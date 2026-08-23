#!/usr/bin/env python3
import argparse, json
from pathlib import Path
from psd_tools import PSDImage

def safe(s): return ''.join(c if c.isalnum() or c in '-_.' else '_' for c in (s or 'layer')).strip('._') or 'layer'
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('psd',type=Path); ap.add_argument('--output-dir',type=Path); a=ap.parse_args()
    out=a.output_dir or a.psd.with_name(a.psd.stem+'_layers'); out.mkdir(parents=True,exist_ok=True)
    psd=PSDImage.open(a.psd); records=[]
    def walk(layer, parents):
        i=len(records); rec={'index':i,'name':layer.name,'kind':layer.kind,'visible':bool(layer.is_visible()),'bbox':[int(layer.left),int(layer.top),int(layer.right),int(layer.bottom)],'parents':parents,'png':None}; records.append(rec)
        if layer.is_group():
            for child in layer: walk(child, parents+[layer.name or 'group'])
        else:
            try: image=layer.composite()
            except Exception:
                try: image=layer.topil()
                except Exception: image=None
            if image is not None:
                name=f'{i:03d}_{safe(layer.name)}.png'; image.save(out/name); rec['png']=name
    for layer in psd: walk(layer,[])
    (out/'layers.json').write_text(json.dumps({'canvas':[psd.width,psd.height],'layers':records},ensure_ascii=False,indent=2),encoding='utf-8')
if __name__=='__main__': main()
