# ddev-agent-browser-display

[![add-on registry](https://img.shields.io/badge/DDEV-Add--on-blue)](https://addons.ddev.com)

A persistent virtual display inside the DDEV **web** container, shared over
VNC and viewable in a browser tab. Built for
[agent-browser](https://github.com/vercel-labs/agent-browser): run it with
`--headed` and watch, live, what your coding agent does in the browser.

## Install

```bash
ddev add-on get aivazashvilitekla/ddev-agent-browser-display
ddev restart
```

Then open `https://<project>.ddev.site:6080/vnc.html` - `<project>` is your
DDEV project name, so for a project called `mysite` that is
`https://mysite.ddev.site:6080/vnc.html` - and click **Connect**. An empty
grey desktop means the display is live.

## Use with agent-browser

Inside the web container (`ddev ssh`, or prefix with `ddev exec`):

```bash
agent-browser open https://<project>.ddev.site --headed
```

Headless stays the default. `--headed` (or `AGENT_BROWSER_HEADED=true`) puts
Chrome on the display; with `DISPLAY` set, agent-browser uses this display
instead of starting a private one.

Three things to know inside a DDEV web container:

- **Apple Silicon / ARM64 hosts:** `agent-browser install` cannot download
  Chrome for Testing (no Linux ARM64 builds). Install Debian's Chromium and
  point agent-browser at it:
  `sudo apt-get install -y chromium`, then add
  `--executable-path /usr/bin/chromium` to your commands.
- **Your site's URL:** use the URL `ddev describe` prints, including any
  non-default router port (e.g. `https://<project>.ddev.site:8443`).
- **DDEV's local certificate:** Chromium inside the container does not trust
  it. Add `--ignore-https-errors`, or trust the CA properly with
  `--ca-cert <path>` (see agent-browser's README).

## What it adds

- Debian packages `xvfb`, `x11vnc`, `novnc`, `websockify` in the web image.
- `DISPLAY=:99` in the web environment.
- Three supervised daemons (`ddev exec supervisorctl status 'webextradaemons:*'`):
  `Xvfb :99` at 1920x1080, `x11vnc` on 5900 (container-internal), and
  `websockify` serving noVNC on 6080.
- Router port 6080 (https) / 6081 (http) for the noVNC page.

## Native VNC viewer instead of noVNC

The raw VNC port is not published by default (a fixed host port collides
across projects). To use macOS Screen Sharing, add `.ddev/docker-compose.vnc.yaml`:

```yaml
services:
  web:
    ports:
      - "5900:5900"
```

then `ddev restart` and open `vnc://127.0.0.1:5900`.

## Security note

The X display has no authentication and the VNC server no password. Both are
reachable only inside the container (X over a local socket, VNC on a port
that is not published). Anything running inside the web container can view
and drive the display - fine for a single-user dev container, which is what
DDEV is.

## Remove

```bash
ddev add-on remove agent-browser-display
ddev restart
```
