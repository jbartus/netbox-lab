# /// script
# requires-python = ">=3.12"
# dependencies = ["fastapi[standard]"]
# ///
# run: uv run ui/app.py
import json
import re
import subprocess
import time
from pathlib import Path
from typing import Literal

import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.templating import Jinja2Templates

HERE = Path(__file__).parent
ROOT = HERE.parent
TFVARS = ROOT / "terraform.tfvars"
LOG = HERE / "run.log"
LOG.touch()

app = FastAPI()
templates = Jinja2Templates(directory=HERE / "templates")
proc = None


def parse():
    s = TFVARS.read_text()
    bools = re.findall(r"^(\w+)\s*=\s*(true|false)", s, re.MULTILINE)
    strs = re.findall(r'^(?!enable_)(\w+)\s*=\s*"(.*)"', s, re.MULTILINE)
    return s, bools, strs


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    _, bools, strs = parse()
    return templates.TemplateResponse(request, "index.html", {"bools": bools, "strs": strs})


@app.post("/save")
async def save(request: Request):
    form = await request.form()
    s, bools, strs = parse()
    vals = {k: "true" if k in form else "false" for k, _ in bools} | {k: json.dumps(form[k]) for k, _ in strs}
    for k, v in vals.items():
        s = re.sub(rf"^({k}\s*=\s*).*", lambda m: m[1] + v, s, flags=re.MULTILINE)
    TFVARS.write_text(s)
    return HTMLResponse("saved")


@app.get("/status", response_class=HTMLResponse)
def status(request: Request):
    out = subprocess.run(["terraform", "output", "-json"], cwd=ROOT, capture_output=True, text=True, check=False).stdout
    return templates.TemplateResponse(request, "status.html", {"outputs": json.loads(out or "{}")})


@app.get("/rc")
def rc():
    return None if proc is None else proc.poll()


@app.get("/tail")
def tail():
    def gen():
        with LOG.open() as f:
            while True:
                line = f.readline()
                if line:
                    yield line
                elif proc is None or proc.poll() is not None:
                    return
                else:
                    time.sleep(0.5)
    return StreamingResponse(gen(), media_type="text/plain")


@app.post("/{cmd}")
def run(cmd: Literal["show", "plan", "apply", "destroy"]):
    global proc
    # a click during a run re-attaches to it instead of starting a second one
    if proc is None or proc.poll() is not None:
        approve = ["-auto-approve"] if cmd in ("apply", "destroy") else []
        with LOG.open("w") as log:
            proc = subprocess.Popen(["terraform", cmd, *approve], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    return RedirectResponse("/tail", status_code=303)


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
