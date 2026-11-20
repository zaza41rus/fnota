#!/usr/bin/env python3
"""Download-only staging. Does not load models, run inference or switch app settings."""
import argparse, concurrent.futures, json, os, pathlib, shutil, subprocess, threading, time
p=argparse.ArgumentParser();p.add_argument('--manifest',required=True);p.add_argument('--destination',required=True);args=p.parse_args()
root=pathlib.Path(args.destination);root.mkdir(parents=True,exist_ok=True)
manifest=json.loads(pathlib.Path(args.manifest).read_text())
lock=threading.Lock();status={'started':time.time(),'phase':'downloading','verification':'not run','models':[]}
for model in manifest:
 status['models'].append({'id':model['id'],'files':[{ 'name':f['name'],'state':'pending','bytes':f['bytes']} for f in model['files']]})
def save():
 temporary=root/'status.json.tmp';temporary.write_text(json.dumps(status,ensure_ascii=False,indent=2));os.replace(temporary,root/'status.json')
def update(i,j,state,error=None):
 with lock:
  status['models'][i]['files'][j]['state']=state
  if error:status['models'][i]['files'][j]['error']=error
  save()
def download(i,model):
 folder=root/model['id'];folder.mkdir(exist_ok=True)
 for j,file in enumerate(model['files']):
  target=folder/file['name'];part=target.with_name(target.name+'.part')
  try:
   if target.exists() and target.stat().st_size==file['bytes']:
    update(i,j,'downloaded');continue
   update(i,j,'downloading')
   local=next((pathlib.Path(x) for x in file.get('local',[]) if pathlib.Path(x).is_file() and pathlib.Path(x).stat().st_size==file['bytes']),None)
   if local:shutil.copyfile(local,part)
   elif not (part.exists() and part.stat().st_size==file['bytes']):
    subprocess.run(['/usr/bin/curl','--fail','--location','--silent','--show-error','--retry','5','--retry-delay','3','--connect-timeout','30','--continue-at','-','--output',str(part),file['remote']],check=True)
   if part.stat().st_size!=file['bytes']:raise RuntimeError('Incomplete download: unexpected byte count')
   os.replace(part,target);update(i,j,'downloaded')
  except Exception as error:update(i,j,'failed',str(error))
with lock:save()
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(lambda pair:download(*pair),enumerate(manifest)))
with lock:
 status['finished']=time.time();status['phase']='failed' if any(f['state']=='failed' for m in status['models'] for f in m['files']) else 'downloaded'
 save()
