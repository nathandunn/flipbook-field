# Flipbook Field

A Godot 4.4 blockout with a graphic-novel look: a block character walks up to a
group of block characters standing in a field under a tree and talks to them in
comic speech balloons. The whole scene and the conversation are generated from a
seed, so they reshuffle on demand.

**Live:** https://flipbook-field.apps.precogsoftwareservices.com

## Repo layout

```
web/           exported Godot web build (committed - the hub cannot run Godot)
project/       Godot 4.4 source; open this folder in the editor
build.sh       re-export the web build
Dockerfile     nginx:alpine serving web/
nginx.conf     gzip_static + correct wasm MIME type
headers.caddy  COOP/COEP, folded into the Caddy block by deploy.sh
```

## Controls

Desktop: `WASD` move, `Shift` run, mouse look (click once to capture the
pointer), `E` / `Space` talk and advance, `R` reshuffle, `T` toggle the ink
pass, `Esc` release the mouse.

Phone: left thumb drags a floating stick to walk, the right side drags to look,
the **TALK** button starts a conversation, and a tap anywhere advances a line.

## Renderer

The desktop project runs **Forward+**. Web and mobile have no Vulkan path, so
they run **Compatibility** (WebGL 2), set per-platform in `project.godot`. The
screen-space ink pass needs the normal-roughness buffer and so exists only under
Forward+; it detects the live renderer at startup and switches itself off rather
than rendering as an opaque sheet across the camera. The inverted-hull outlines
still draw, so the web build looks nearly identical - it just loses the interior
crease lines where the trunk meets the grass.

## Rebuilding

```
./build.sh /path/to/godot4
```

That re-exports `web/` and regenerates `index.wasm.gz` / `index.js.gz`. Both
`.gz` files must be rebuilt with every export or nginx's `gzip_static` will hand
out a stale compressed copy of a fresh wasm.

## The look, in short

1. `project/shaders/toon.gdshader` - banded half-lambert with a *tinted* (cool
   purple) shadow rather than a darker one.
2. `project/shaders/outline.gdshader` - inverted-hull ink, expanded along
   `normalize(VERTEX)` because box meshes have split normals and expanding along
   those leaves a gap at every corner. Thickness is angular, so line weight holds
   constant with distance.
3. `project/shaders/ink_post.gdshader` - Forward+ only; depth + normal edge
   detect for interior creases.

Animation is quantised to 12 fps in `block_figure.gd`. One `floor()` call, and
it is most of what makes the figures read as drawn rather than simulated.

## Swapping in hand-drawn art

`BlockFigure` is the stand-in. The joint names and local axes are the contract a
replacement has to match: arms and legs pivot at shoulder and hip, `rotation.x`
swings forward, `-Z` is the direction the character faces. Anything that keeps
those drops into `Npc.create()` and `Player._ready()` without touching the rest.

`radial_expand` on the outline shader should be turned **off** for organic meshes
with smooth normals; it is on because everything here is boxes.
