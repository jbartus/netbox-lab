# /// script
# requires-python = ">=3.12"
# dependencies = ["fastapi[standard]"]
# ///
# run: uv run ui/app.py
import asyncio
import fcntl
import json
import os
import pty
import re
import shutil
import signal
import struct
import subprocess
import termios
import threading
import time
from pathlib import Path
from typing import Literal
from urllib.parse import urlsplit

import uvicorn
from fastapi import FastAPI, Request, Response, WebSocket
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.templating import Jinja2Templates

HERE = Path(__file__).parent
ROOT = HERE.parent
TFVARS = ROOT / "terraform.tfvars"
STATE = ROOT / "terraform.tfstate"
LOG = HERE / "run.log"
LOG.touch()
# shell tab sessions live on a private tmux server, one session per host, so they outlive the page
# and can be read from outside it: tmux -L lab capture-pane -p -t <host>
TMUX = ["tmux", "-L", "lab"]

app = FastAPI()
# this server runs terraform and opens root shells, so it only answers its own page: the host check stops
# DNS rebinding, and the origin check stops any other site open in the browser from posting or opening a shell
app.add_middleware(TrustedHostMiddleware, allowed_hosts=["127.0.0.1", "localhost"])
templates = Jinja2Templates(directory=HERE / "templates")
proc = None


def same_origin(headers):
    origin = headers.get("origin")
    return origin is None or urlsplit(origin).netloc == headers.get("host")


@app.middleware("http")
async def only_this_page(request: Request, call_next):
    if not same_origin(request.headers):
        return Response(status_code=403)
    return await call_next(request)


def parse():
    s = TFVARS.read_text()
    bools = re.findall(r"^(\w+)\s*=\s*(true|false)", s, re.MULTILINE)
    strs = re.findall(r'^(?!enable_)(\w+)\s*=\s*"(.*)"', s, re.MULTILINE)
    return s, bools, strs


def blocks():
    # top-level resource and module blocks in the .tf files, by state address, with their text
    out = {}
    for tf in ROOT.glob("*.tf"):
        s = tf.read_text()
        for m in re.finditer(r'^(resource|module)\s+"([^"]+)"(?:\s+"([^"]+)")?\s*\{', s, re.MULTILINE):
            depth, i = 1, m.end()
            while depth and i < len(s):
                depth += {"{": 1, "}": -1}.get(s[i], 0)
                i += 1
            out[f"{m[2]}.{m[3]}" if m[1] == "resource" else f"module.{m[2]}"] = s[m.start() : i]
    return out


@app.get("/locked")
def locked():
    # every variable used by something terraform's state says is deployed; nothing is remembered here,
    # so a destroy unlocks things as their resources go
    if not STATE.exists():
        return set()
    resources = json.loads(STATE.read_text() or "{}").get("resources", [])
    deployed = {
        # a resource inside a module counts as the top-level module block that made it
        r.get("module", f"{r['type']}.{r['name']}").split(".module.")[0]
        for r in resources
        if r["mode"] == "managed"
    }
    return {v for addr, text in blocks().items() if addr in deployed for v in re.findall(r"var\.(\w+)", text)}


@app.get("/values")
def values():
    _, bools, strs = parse()
    return {k: v == "true" for k, v in bools} | dict(strs)


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    _, bools, strs = parse()
    return templates.TemplateResponse(request, "index.html", {"bools": bools, "strs": strs})


@app.post("/save")
async def save(request: Request):
    form = await request.form()
    s, bools, strs = parse()
    # locked inputs are disabled, so they're missing from the form rather than off or empty
    lock = locked()
    vals = {k: "true" if k in form else "false" for k, _ in bools if k not in lock}
    vals |= {k: json.dumps(form[k]) for k, _ in strs if k not in lock}
    for k, v in vals.items():
        s = re.sub(rf"^({k}\s*=\s*).*", lambda m: m[1] + v, s, flags=re.MULTILINE)
    TFVARS.write_text(s)
    return HTMLResponse("saved")


def tf_outputs():
    out = subprocess.run(["terraform", "output", "-json"], cwd=ROOT, capture_output=True, text=True, check=False).stdout
    return json.loads(out or "{}")


@app.get("/output", response_class=HTMLResponse)
def output(request: Request):
    return templates.TemplateResponse(request, "output.html", {"outputs": tf_outputs()})


@app.get("/hosts")
def hosts():
    return {k.removesuffix("_ssm_command"): o["value"] for k, o in tf_outputs().items() if k.endswith("_ssm_command")}


@app.websocket("/shell/{host}")
async def shell(ws: WebSocket, host: str):
    if not same_origin(ws.headers):
        return await ws.close()  # before accept, so the handshake is refused
    await ws.accept()
    # say what's missing in the tab itself, instead of the session just closing
    installs = {"tmux": "brew install tmux", "session-manager-plugin": "brew install --cask session-manager-plugin"}
    if missing := [tool for tool in installs if not shutil.which(tool)]:
        fix = "; ".join(installs[tool] for tool in missing)
        await ws.send_bytes(f"the shell tab needs {' and '.join(missing)}: {fix}\r\n".encode())
        return await ws.close()
    cmd = hosts().get(host)
    if cmd is None:
        return await ws.close()
    if subprocess.run([*TMUX, "has-session", "-t", host], capture_output=True).returncode:
        # straight to a root shell, the first thing anyone does on these anyway
        cmd += " --document-name AWS-StartInteractiveCommand --parameters command='sudo -i'"
        # a new instance's ssm agent takes a minute or two to register, so keep trying until a session opens;
        # typing exit ends it cleanly, which ends the loop and the tmux session with it
        retry = f"until {cmd}; do echo 'waiting for the ssm agent...'; sleep 5; done"
        subprocess.run([*TMUX, "new-session", "-d", "-s", host, retry], check=True)
    # the page is just another tmux client, attached through a pty
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.execvp("tmux", [*TMUX, "attach", "-t", host])
    loop = asyncio.get_running_loop()
    out = asyncio.Queue()

    def readable():
        try:
            out.put_nowait(os.read(fd, 65536))
        except OSError:  # the client exited, e.g. the ssm session ended
            loop.remove_reader(fd)
            out.put_nowait(b"")

    async def pump():
        while data := await out.get():
            await ws.send_bytes(data)
        await ws.close()

    loop.add_reader(fd, readable)
    task = asyncio.create_task(pump())
    try:
        # bytes are keystrokes, text is a resize
        while (msg := await ws.receive())["type"] != "websocket.disconnect":
            if msg.get("bytes"):
                os.write(fd, msg["bytes"])
            elif msg.get("text"):
                size = json.loads(msg["text"])
                fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", size["rows"], size["cols"], 0, 0))
    finally:
        task.cancel()
        loop.remove_reader(fd)
        os.kill(pid, signal.SIGHUP)  # detaches this client; the tmux session keeps running
        os.close(fd)
        os.waitpid(pid, 0)


@app.get("/last")
def last():
    # the most recent terraform run; rc is null while it's still going
    return None if proc is None else {"cmd": proc.args[1], "rc": proc.poll()}


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
        if cmd == "destroy":
            threading.Thread(target=close_shells, args=(proc,), daemon=True).start()
    return RedirectResponse("/tail", status_code=303)


def close_shells(destroy):
    # an ssm session doesn't notice its instance is gone, so once a destroy succeeds the shell tab's sessions
    # would hang on forever
    if destroy.wait() == 0:
        subprocess.run([*TMUX, "kill-server"], capture_output=True)


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
