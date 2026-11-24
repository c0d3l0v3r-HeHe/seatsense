"""Re-record the demo: run the API on :8001, then `python record.py  python compose.py` (needs playwright, imageio-ffmpeg).
"""
"""Scripted walkthrough of the SeatSense app, recorded at phone size. Writes rec/*.webm and marks.json."""
import asyncio, json, time, shutil
from playwright.async_api import async_playwright

marks = []
async def main():
    shutil.rmtree('rec', ignore_errors=True)
    async with async_playwright() as p:
        b = await p.chromium.launch(channel='chrome')
        ctx = await b.new_context(viewport={'width': 412, 'height': 892}, device_scale_factor=2,
                                  record_video_dir='rec', record_video_size={'width': 824, 'height': 1784})
        pg = await ctx.new_page()
        t0 = time.monotonic()
        def mark(key): marks.append((key, round(time.monotonic() - t0, 2)))
        w = pg.wait_for_timeout
        await pg.goto('http://localhost:8001/?theme=light'); await w(3000)
        mark('home'); await w(4500)
        await pg.mouse.click(200, 150); await w(1800)
        mark('results'); await w(4000)
        await pg.mouse.wheel(0, 260); await w(3500)
        await pg.mouse.wheel(0, -260); await w(800)
        await pg.mouse.click(200, 270); await w(1200)
        mark('detail'); await w(3500)
        await pg.mouse.click(370, 431); await w(3000)
        await pg.mouse.wheel(0, 420); await w(3000)
        await pg.mouse.wheel(0, -2000); await w(900)
        await pg.mouse.click(28, 24); await w(900)
        await pg.mouse.click(28, 28); await w(1200)
        await pg.mouse.click(159, 855); await w(1800)
        mark('routes'); await w(3000)
        await pg.mouse.click(291, 520); await w(3200)
        await pg.mouse.wheel(0, 520); await w(3200)
        await pg.mouse.click(253, 855); await w(1500)
        mark('hotspots'); await w(2500)
        await pg.mouse.move(129, 223); await pg.mouse.down()
        for k in range(1, 21):
            await pg.mouse.move(129 + (282 - 129) * k / 20, 223); await w(40)
        await pg.mouse.up(); await w(3500)
        await pg.mouse.click(346, 855); await w(1500)
        mark('about'); await w(2500)
        await pg.mouse.wheel(0, 500); await w(3500)
        await pg.mouse.click(65, 855); await w(1000)
        mark('end'); await w(3500)
        await ctx.close(); await b.close()
    json.dump(marks, open('marks.json', 'w'))
    print(marks)
asyncio.run(main())
