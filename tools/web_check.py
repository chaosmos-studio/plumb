"""Plays the live web build with real mouse events over the DevTools protocol: Play, a downward swipe
(level 1's one-move solution), then Next level, screenshotting after each step.

Run: python3 tools/web_check.py [out_dir] [url]   (needs Google Chrome and websocket-client)
The headless Chrome screenshot only proves the page boots; this proves input, a solve and the result card
all work in the browser. Run it inside a capped scope, since Chrome can use a lot of memory.
"""
import base64, json, os, subprocess, sys, time, urllib.request
import websocket

SP = sys.argv[1] if len(sys.argv) > 1 else "build/web_check"
URL = sys.argv[2] if len(sys.argv) > 2 else "https://shravangoswami.com/plumb/"
W, H = 405, 720
os.makedirs(SP, exist_ok=True)
chrome = subprocess.Popen(["google-chrome", "--headless=new", "--no-sandbox", "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--window-size=%d,%d" % (W, H),
    "--user-data-dir=%s/chrome-plumb-cdp" % SP, "--remote-debugging-port=9334", "--remote-allow-origins=*",
    "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    for _ in range(50):
        try:
            tabs = json.load(urllib.request.urlopen("http://127.0.0.1:9334/json"))
            page = [t for t in tabs if t["type"] == "page"][0]
            break
        except Exception:
            time.sleep(0.2)
    ws = websocket.create_connection(page["webSocketDebuggerUrl"], timeout=60)
    n = [0]
    def call(method, **params):
        n[0] += 1
        ws.send(json.dumps({"id": n[0], "method": method, "params": params}))
        while True:
            msg = json.loads(ws.recv())
            if msg.get("id") == n[0]:
                return msg.get("result", {})
    def shot(name):
        data = call("Page.captureScreenshot", format="png")["data"]
        open("%s/tilt_web_%s.png" % (SP, name), "wb").write(base64.b64decode(data))
        print("shot", name)
    def mouse(kind, x, y, buttons):
        call("Input.dispatchMouseEvent", type=kind, x=x, y=y, button="left", buttons=buttons, clickCount=1)
    def click(x, y):
        mouse("mouseMoved", x, y, 0); time.sleep(0.05)
        mouse("mousePressed", x, y, 1); time.sleep(0.08)
        mouse("mouseReleased", x, y, 0)
    def swipe(x, y, dx, dy):
        mouse("mouseMoved", x, y, 0); time.sleep(0.05)
        mouse("mousePressed", x, y, 1)
        for k in range(1, 9):
            time.sleep(0.02)
            mouse("mouseMoved", x + dx * k / 8, y + dy * k / 8, 1)
        mouse("mouseReleased", x + dx, y + dy, 0)
    call("Emulation.setDeviceMetricsOverride", width=W, height=H, deviceScaleFactor=1, mobile=False)
    call("Page.enable")
    call("Page.navigate", url=URL)
    for k in range(120):
        time.sleep(1)
        if call("Runtime.evaluate", expression="document.getElementById('status') === null")["result"]["value"]:
            print("engine started after %d s" % (k + 1))
            break
    time.sleep(2)
    shot("1_title")
    click(202, 526)
    time.sleep(2.0)
    shot("2_level1")
    swipe(202, 330, 0, 120)
    time.sleep(3.0)
    shot("3_solved")
    click(202, 420)
    time.sleep(2.5)
    shot("4_level2")
finally:
    chrome.terminate()
