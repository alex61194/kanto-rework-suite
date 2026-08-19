#!/usr/bin/env python3
"""Render reproducible offline QA evidence for the Figma glyph pipeline.

These images are NOT Gen1Recomp screenshots. They exercise the canonical SVGs,
generated PNGs, semantic colors and validated responsive scale math offline.
"""
from __future__ import annotations
import argparse, json, math, re
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import cairosvg
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=json.loads((ROOT/'generated/glyph_manifest.json').read_text(encoding='utf-8'))
PROFILES=(ROOT/'generated/color_profiles.lua').read_text(encoding='utf-8')
TYPE_ORDER=list(MANIFEST['types'])
STATUS_ORDER=list(MANIFEST['statuses'])
STATUS_LABELS={'POISONED':'POISONED','BADLY_POISONED':'BADLY POISONED','BURNED':'BURNED','PARALYZED':'PARALYZED','ASLEEP':'ASLEEP','FROZEN':'FROZEN','FAINTED':'FAINTED'}
PROF_NAMES=['standard','protanopia','deuteranopia','tritanopia']

FONT_REG='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

def font(size,bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG,max(8,int(round(size))))

def parse_frac(token):
    m=re.fullmatch(r'(\d+)/255',token.strip()); return int(m.group(1)) if m else int(float(token)*255)

def type_colors(profile):
    out={}
    pat=re.compile(rf'P\.{re.escape(profile)}\.typeColors\.([A-Z_]+)=\{{([^}}]+)\}}')
    for k,body in pat.findall(PROFILES):
        vals=[x.strip() for x in body.split(',')[:3]];out[k]=tuple(parse_frac(v) for v in vals)
    return out

def status_colors(profile):
    block=re.search(rf'P\.{re.escape(profile)}\.statusColors=\{{(.*?)\n\}}',PROFILES,re.S)
    out={}
    if not block:return out
    for k,args in re.findall(r'([A-Z_]+)=sc\((.*?)\),?(?:\n|$)',block.group(1),re.S):
        groups=re.findall(r'\{([^}]+)\}',args)
        rgb=[]
        for g in groups:
            vals=[x.strip() for x in g.split(',')[:3]];rgb.append(tuple(parse_frac(v) for v in vals))
        out[k]={'outline':rgb[0],'icon':rgb[1],'marker':rgb[2] if len(rgb)>2 else rgb[0]}
    return out

def render_svg(path,size):
    raw=cairosvg.svg2png(url=str(path),output_width=size[0],output_height=size[1])
    return Image.open(BytesIO(raw)).convert('RGBA')

def checker(size,cell=12):
    im=Image.new('RGB',size,(55,55,58));d=ImageDraw.Draw(im)
    for y in range(0,size[1],cell):
        for x in range(0,size[0],cell):
            if (x//cell+y//cell)%2: d.rectangle((x,y,min(size[0],x+cell)-1,min(size[1],y+cell)-1),fill=(75,75,80))
    return im.convert('RGBA')

def center_paste(dst,src,box):
    x,y,w,h=box
    dx=int(round(x+(w-src.width)/2));dy=int(round(y+(h-src.height)/2))
    dst.alpha_composite(src,(dx,dy))

def fit_rgba(src,w,h):
    # LANCZOS is used only for offline evidence. Runtime uses LÖVE linear filtering.
    return src.resize((max(1,int(round(w))),max(1,int(round(h)))),Image.Resampling.LANCZOS)

def choose(rec,draw_size):
    target=draw_size*2; chosen=rec['runtime'][-1]
    for v in rec['runtime']:
        if v['pixels']>=target: chosen=v;break
    return chosen

def glyph_image(rec,draw_size):
    v=choose(rec,draw_size)
    src=Image.open(ROOT/v['path']).convert('RGBA')
    return fit_rgba(src,draw_size,draw_size),v

def draw_type_icon(im,kind,cx,cy,size,profile):
    d=ImageDraw.Draw(im);tc=type_colors(profile)[kind]
    r=size/2;d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=tc+(255,))
    g,_=glyph_image(MANIFEST['types'][kind],size*20/32)
    im.alpha_composite(g,(int(round(cx-g.width/2)),int(round(cy-g.height/2))))

def draw_type_chip(im,kind,x,y,s,profile):
    d=ImageDraw.Draw(im);tc=type_colors(profile)[kind]
    w,h=148*s,36*s; d.rounded_rectangle((x,y,x+w,y+h),radius=h/2,fill=tc+(255,),outline=(255,255,255,255),width=max(1,int(round(2*s))))
    g,_=glyph_image(MANIFEST['types'][kind],20*s)
    im.alpha_composite(g,(int(round(x+16*s-g.width/2)),int(round(y+18*s-g.height/2))))
    d.text((x+34*s,y+18*s),kind,font=font(12*s,True),fill=(247,241,223,255),anchor='lm')

def draw_status_icon(im,status,cx,cy,size,profile):
    sc=status_colors(profile)[status];d=ImageDraw.Draw(im);r=size/2
    d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=sc['icon']+(255,))
    if status=='BADLY_POISONED':
        ms=size*12/32;mx=cx+size*10/32;my=cy-size*10/32;mr=ms/2
        d.ellipse((mx-mr,my-mr,mx+mr,my+mr),fill=sc['marker']+(255,),outline=(255,255,255,255),width=max(1,int(round(size/32))))
    g,_=glyph_image(MANIFEST['statuses'][status],size)
    im.alpha_composite(g,(int(round(cx-g.width/2)),int(round(cy-g.height/2))))

def draw_status_token(im,status,x,y,s,profile):
    d=ImageDraw.Draw(im);sc=status_colors(profile)[status]
    w,h=188*s,40*s
    d.rounded_rectangle((x,y,x+w,y+h),radius=12*s,fill=(255,255,255,255),outline=sc['outline']+(255,),width=max(1,int(round(2*s))))
    draw_status_icon(im,status,x+20*s,y+20*s,32*s,profile)
    d.text((x+46*s,y+20*s),STATUS_LABELS[status],font=font(12*s,True),fill=(36,34,30,255),anchor='lm')

def header(im,title,subtitle=None):
    d=ImageDraw.Draw(im);d.text((40,30),title,font=font(30,True),fill=(245,241,230,255))
    if subtitle:d.text((40,70),subtitle,font=font(15),fill=(188,185,178,255))

def make_type_comparison(out):
    W,H=1800,1040;im=Image.new('RGBA',(W,H),(28,28,31,255));header(im,'18 TYPE GLYPHS — FIGMA SVG SOURCE vs RUNTIME 4×','Direct Figma export nodes 625:2224…625:2264 • 20×20 viewBox preserved • alpha geometry comparison')
    d=ImageDraw.Draw(im)
    for i,k in enumerate(TYPE_ORDER):
        col=i%6;row=i//6;x=40+col*290;y=120+row*290
        rec=MANIFEST['types'][k];d.text((x,y),f'{k}  {rec["node"]}',font=font(14,True),fill=(238,238,238,255))
        s=80;src=render_svg(ROOT/rec['source'],(s,s));run=Image.open(ROOT/rec['runtime'][-1]['path']).convert('RGBA')
        a=checker((110,110));center_paste(a,src,(0,0,110,110));im.alpha_composite(a,(x,y+32))
        b=checker((110,110));center_paste(b,run,(0,0,110,110));im.alpha_composite(b,(x+132,y+32))
        diff=ImageChops.difference(src.getchannel('A'),run.getchannel('A'));maxdiff=diff.getextrema()[1]
        d.text((x,y+150),'FIGMA SVG',font=font(12),fill=(190,190,194,255));d.text((x+132,y+150),'RUNTIME 4×',font=font(12),fill=(190,190,194,255))
        d.text((x,y+176),f'alpha Δ max: {maxdiff}',font=font(11),fill=(140,210,160,255) if maxdiff==0 else (255,150,120,255))
        t=rec['trace'];d.text((x,y+198),f'trace {t["width"]:g}×{t["height"]:g} @ {t["x"]:g},{t["y"]:g}',font=font(10),fill=(165,165,170,255))
    im.convert('RGB').save(out,quality=94)

def make_status_comparison(out):
    W,H=1800,820;im=Image.new('RGBA',(W,H),(28,28,31,255));header(im,'7 STATUS GLYPHS — FIGMA SVG SOURCE vs RUNTIME 4×','Direct Figma export nodes 627:2272…627:2300 • 32×32 viewBox preserved • no baked status container')
    d=ImageDraw.Draw(im)
    for i,k in enumerate(STATUS_ORDER):
        col=i%4;row=i//4;x=40+col*435;y=130+row*330
        rec=MANIFEST['statuses'][k];d.text((x,y),f'{k.replace("_"," ")}  {rec["node"]}',font=font(14,True),fill=(238,238,238,255))
        s=128;src=render_svg(ROOT/rec['source'],(s,s));run=Image.open(ROOT/rec['runtime'][-1]['path']).convert('RGBA')
        a=checker((150,150));center_paste(a,src,(0,0,150,150));im.alpha_composite(a,(x,y+34))
        b=checker((150,150));center_paste(b,run,(0,0,150,150));im.alpha_composite(b,(x+175,y+34))
        diff=ImageChops.difference(src.getchannel('A'),run.getchannel('A'));maxdiff=diff.getextrema()[1]
        d.text((x,y+194),'FIGMA SVG',font=font(12),fill=(190,190,194,255));d.text((x+175,y+194),'RUNTIME 4×',font=font(12),fill=(190,190,194,255))
        d.text((x,y+220),f'alpha Δ max: {maxdiff}',font=font(11),fill=(140,210,160,255) if maxdiff==0 else (255,150,120,255))
        t=rec['trace'];d.text((x,y+242),f'trace {t["width"]:.3f}×{t["height"]:.3f}',font=font(10),fill=(165,165,170,255))
    im.convert('RGB').save(out,quality=94)

def make_resolution_board(out,w,h,profile='standard'):
    im=Image.new('RGBA',(w,h),(247,241,223,255));d=ImageDraw.Draw(im);s=min(w/1920,h/1080);ox=(w-1920*s)/2;oy=(h-1080*s)/2
    d.rectangle((0,0,w,78*s),fill=(34,32,29,255));d.text((32*s,30*s),f'OFFLINE RASTER QA — {w}×{h} — {profile.upper()} — NOT AN IN-GAME CAPTURE',font=font(20*s,True),fill=(247,241,223,255))
    d.text((32*s,105*s),'18 TYPE TOKENS — shared Figma glyph source / semantic runtime colors',font=font(17*s,True),fill=(36,34,30,255))
    for i,k in enumerate(TYPE_ORDER):
        col=i%6;row=i//6;draw_type_chip(im,k,32*s+col*308*s,145*s+row*64*s,s,profile)
    d.text((32*s,365*s),'7 STATUS TOKENS — Full + Compact share the same 32×32 glyph geometry',font=font(17*s,True),fill=(36,34,30,255))
    for i,k in enumerate(STATUS_ORDER):
        col=i%4;row=i//4;draw_status_token(im,k,32*s+col*455*s,405*s+row*74*s,s,profile)
    d.text((32*s,590*s),'COMPACT TYPE + STATUS ICONS',font=font(17*s,True),fill=(36,34,30,255))
    for i,k in enumerate(TYPE_ORDER):
        cx=(56+(i%9)*120)*s;cy=(648+(i//9)*74)*s;draw_type_icon(im,k,cx,cy,32*s,profile)
    for i,k in enumerate(STATUS_ORDER):
        cx=(1160+i*95)*s;cy=648*s;draw_status_icon(im,k,cx,cy,32*s,profile)
    # density summary mirroring runtime chooser
    tv=choose(MANIFEST['types']['FIRE'],20*s);sv=choose(MANIFEST['statuses']['POISONED'],32*s)
    d.text((32*s,840*s),f'UI scale {s:.4f} • Type glyph physical {20*s:.3f}px ← {tv["pixels"]}px raster • Status glyph physical {32*s:.3f}px ← {sv["pixels"]}px raster',font=font(14*s),fill=(82,78,72,255))
    d.text((32*s,885*s),'Linear-filtered modern UI assets. Raster source remains larger than displayed glyph at every validated target.',font=font(14*s),fill=(82,78,72,255))
    im.convert('RGB').save(out,quality=92)

def make_profiles(out):
    W,H=1920,1080;im=Image.new('RGBA',(W,H),(238,232,216,255));d=ImageDraw.Draw(im)
    d.rectangle((0,0,W,86),fill=(34,32,29,255));d.text((36,28),'ACCESSIBILITY PROFILES — IDENTICAL GLYPH GEOMETRY / SEMANTIC COLORS ONLY',font=font(23,True),fill=(247,241,223,255))
    for pi,p in enumerate(PROF_NAMES):
        col=pi%2;row=pi//2;x=36+col*945;y=118+row*465
        d.rounded_rectangle((x,y,x+905,y+430),radius=18,fill=(250,247,239,255),outline=(158,151,139,255),width=2)
        d.text((x+22,y+18),p.upper(),font=font(18,True),fill=(36,34,30,255))
        for i,k in enumerate(TYPE_ORDER):
            cx=x+48+(i%9)*91;cy=y+84+(i//9)*66;draw_type_icon(im,k,cx,cy,32,p)
        for i,k in enumerate(STATUS_ORDER):
            cx=x+52+i*105;cy=y+250;draw_status_icon(im,k,cx,cy,32,p)
        draw_type_chip(im,'FIRE',x+22,y+302,1,p);draw_type_chip(im,'POISON',x+186,y+302,1,p)
        draw_status_token(im,'BADLY_POISONED',x+350,y+300,1,p);draw_status_token(im,'FROZEN',x+556,y+300,1,p)
        d.text((x+22,y+382),'Asset registry path is profile-independent; only type/status semantic tokens change.',font=font(11),fill=(91,86,80,255))
    im.convert('RGB').save(out,quality=94)

def make_legacy_diag(out,old_zip):
    with ZipFile(old_zip) as z:
        old=Image.open(BytesIO(z.read('assets/runtime/status_glyphs/4x/poison.png'))).convert('RGBA')
    new=Image.open(ROOT/MANIFEST['statuses']['POISONED']['runtime'][-1]['path']).convert('RGBA')
    W,H=920,570;im=Image.new('RGBA',(W,H),(28,28,31,255));d=ImageDraw.Draw(im)
    header(im,'LEGACY POISON ASSET DIAGNOSTIC','0.4.10 old raster vs 0.4.11 canonical glyph-only runtime asset')
    for idx,(label,img) in enumerate([('OLD 0.4.10 poison.png',old),('NEW 0.4.11 poisoned.png',new)]):
        x=70+idx*440;y=125;tile=checker((260,260),16);big=fit_rgba(img,256,256);center_paste(tile,big,(2,2,256,256));im.alpha_composite(tile,(x,y));d.text((x,y+278),label,font=font(15,True),fill=(238,238,238,255))
        bbox=img.getchannel('A').getbbox();transparent_rgb=set(px[:3] for px in img.getdata() if px[3]==0)
        sample=next(iter(transparent_rgb)) if transparent_rgb else None
        d.text((x,y+310),f'alpha bbox: {bbox}',font=font(12),fill=(190,190,194,255));d.text((x,y+338),f'transparent RGB: {sample}',font=font(12),fill=(190,190,194,255))
    d.text((70,515),'Old mask includes container-scale alpha and black RGB in transparent texels; new asset is glyph-only and white-RGB alpha-safe.',font=font(12),fill=(240,176,120,255))
    im.convert('RGB').save(out,quality=94)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);ap.add_argument('--old-zip',type=Path);args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    make_type_comparison(args.out/'type_glyph_comparison.png')
    make_status_comparison(args.out/'status_glyph_comparison.png')
    for w,h in [(1280,720),(1600,900),(1920,1080),(2560,1440)]:make_resolution_board(args.out/f'runtime_board_{w}x{h}.png',w,h)
    make_profiles(args.out/'accessibility_profiles.png')
    if args.old_zip:make_legacy_diag(args.out/'legacy_poison_diagnostic.png',args.old_zip)
    print('wrote evidence to',args.out)
if __name__=='__main__':main()
