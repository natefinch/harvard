import sys, numpy as np
from PIL import Image
from scipy import ndimage
A='/Users/natefinch/src/github.com/natefinch/harvard/game/assets/'

def key(im):
    a=np.asarray(im.convert('RGB')).astype(np.float32)
    r,g,b=a[...,0],a[...,1],a[...,2]
    # magenta distance: high r, high b, low g
    mag=np.minimum(r,b)-g
    alpha=np.clip((150-mag)/60.0,0,1)
    # despill
    spill=np.clip(np.minimum(r,b)-g-20,0,None)*(1-alpha)*0+0
    out=a.copy()
    m=np.minimum(r,b)
    over=np.clip(m-np.maximum(g,40)-30,0,None)*0.6
    out[...,0]-=over; out[...,2]-=over
    out=np.clip(out,0,255)
    rgba=np.dstack([out,alpha*255]).astype(np.uint8)
    return Image.fromarray(rgba,'RGBA'), alpha

def cells(path, rows, cols, names, outdir, maxh=None):
    im=Image.open(A+'raw/'+path)
    rgba,alpha=key(im)
    W,H=im.size
    cw,ch=W/cols,H/rows
    import os; os.makedirs(A+outdir,exist_ok=True)
    for r in range(rows):
        for c in range(cols):
            n=names[r][c]
            if not n: continue
            x0,y0=int(c*cw),int(r*ch); x1,y1=int((c+1)*cw),int((r+1)*ch)
            al=alpha[y0:y1,x0:x1]>0.5
            lab,k=ndimage.label(al)
            if k==0: continue
            sizes=ndimage.sum(al,lab,range(1,k+1))
            keep=np.isin(lab,[i+1 for i,sz in enumerate(sizes) if sz>max(sizes)*(0.002 if n=="hollow" else 0.15)])
            keep=ndimage.binary_dilation(keep,iterations=3)
            cell=np.asarray(rgba)[y0:y1,x0:x1].copy()
            cell[...,3]=np.where(keep,cell[...,3],0)
            ys,xs=np.where(cell[...,3]>8)
            crop=Image.fromarray(cell[ys.min():ys.max()+1,xs.min():xs.max()+1],'RGBA')
            if maxh and crop.height>maxh:
                crop=crop.resize((round(crop.width*maxh/crop.height),maxh),Image.LANCZOS)
            crop.save(A+outdir+'/'+n+'.png')
            print(n,crop.size)

cells('party_sheet.png',4,3,[['sam_down','sam_up','sam_side'],['dani_down','dani_up','dani_side'],['dusty_down','dusty_up','dusty_side'],['kit_down','kit_up','kit_side']],'sprites',maxh=None)
cells('npc_sheet.png',3,4,[['ada','nell','chief','mary'],['abner','lark','deacon','farmer'],['girl','teen','lantern_man','coveralls']],'sprites')
cells('enemy_sheet.png',3,3,[['raccoon','goose','cyclist'],['hollow','coveralls','lantern_man'],['teamster','wisp','scarecrow']],'enemies')

# portraits: grid 3x4 with dark bg, just crop cells w/ small inset
im=Image.open(A+'raw/portrait_sheet.png').convert('RGB')
names=[['sam','dani','dusty','kit'],['ada','nell','chief','mary'],['abner','lark','deacon','rowan']]
import os; os.makedirs(A+'portraits',exist_ok=True)
W,H=im.size
for r in range(3):
    for c in range(4):
        x0,y0=c*W/4,r*H/3
        cr=im.crop((int(x0)+6,int(y0)+6,int(x0+W/4)-6,int(y0+H/3)-6)).resize((256,224),Image.LANCZOS)
        cr.save(A+'portraits/'+names[r][c]+'.png')
