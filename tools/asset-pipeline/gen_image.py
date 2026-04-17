#!/usr/bin/env python3
"""Generate image via Gemini 2.5 Flash Image Preview (nano-banana)."""
import os
import sys
import json
import base64
import urllib.request
import urllib.error

def generate(api_key: str, prompt: str, out_path: str) -> None:
    model = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-2.5-flash-image")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE", "TEXT"]},
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"HTTP {e.code}: {e.read().decode('utf-8', errors='replace')}\n")
        sys.exit(1)

    parts = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    for part in parts:
        inline = part.get("inlineData") or part.get("inline_data")
        if inline and "data" in inline:
            with open(out_path, "wb") as f:
                f.write(base64.b64decode(inline["data"]))
            print(f"saved {out_path} ({os.path.getsize(out_path)} bytes)")
            return
    sys.stderr.write(f"no image in response: {json.dumps(data)[:500]}\n")
    sys.exit(2)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.stderr.write("usage: gen_image.py <prompt_file> <out_path>\n")
        sys.exit(1)
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.stderr.write("GEMINI_API_KEY not set\n")
        sys.exit(1)
    with open(sys.argv[1]) as f:
        prompt = f.read().strip()
    generate(key, prompt, sys.argv[2])
