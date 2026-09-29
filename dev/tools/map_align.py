import sys, numpy as np
from PIL import Image
def check(new, old):
    N=Image.open(new); O=Image.open(old).convert('RGB')
    n=np.asarray(N.convert('L').resize(O.size),dtype=np.float32); o=np.asarray(O.convert('L'),dtype=np.float32)
    H,W=o.shape; res=[]
    for y in np.linspace(40,H-140,5).astype(int):
        for x in np.linspace(40,W-140,6).astype(int):
            a=o[y:y+96,x:x+96]; a=a-a.mean(); best=(-2,0,0)
            for dy in range(-20,21,2):
                for dx in range(-20,21,2):
                    b=n[y+dy:y+dy+96,x+dx:x+dx+96]
                    if b.shape!=a.shape: continue
                    b=b-b.mean(); c=(a*b).sum()/(np.sqrt((a*a).sum()*(b*b).sum())+1e-6)
                    if c>best[0]: best=(c,dx,dy)
            res.append(best)
    offs=[(r[1],r[2]) for r in res if r[0]>0.6]
    print(new, N.size, 'patches', len(res), 'good', len(offs), 'max|off|', max([max(abs(a),abs(b)) for a,b in offs] or [99]), 'mean corr %.2f'%np.mean([r[0] for r in res]))
for a,b in zip(sys.argv[1::2], sys.argv[2::2]): check(a,b)
