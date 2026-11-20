import json,hashlib,pathlib,subprocess,time
root=pathlib.Path('/Volumes/T9/UniversalMac/ModelDownloads/2026-10-25');out=pathlib.Path('UniversalMac/test-results/speech-catalog');results=[]
for m in json.loads((root/'manifest.json').read_text()):
 row={'id':m['id'],'integrity':True,'files':[],'tests':[]};folder=root/m['id']
 for f in m['files']:
  p=folder/f['name'];h=hashlib.sha256()
  with p.open('rb') as stream:
   for chunk in iter(lambda:stream.read(8*1024*1024),b''):h.update(chunk)
  ok=p.stat().st_size==f['bytes'] and h.hexdigest()==f['sha256'];row['integrity'] &=ok;row['files'].append({'name':f['name'],'ok':ok})
 kind='whisper' if m['id'].startswith('whisper') else 'parakeet' if m['id'].startswith('parakeet') else 'sense' if m['id'].startswith('sense') else 'ctc'
 for lang,audio in [('ru','/tmp/universalmac-speech-test.wav'),('en','/tmp/um-english.wav')]:
  if kind=='ctc' and lang=='en' or kind=='sense' and lang=='ru':continue
  start=time.monotonic()
  try:
   r=subprocess.run(['/tmp/um-catalog-test',str(folder),kind,audio],capture_output=True,text=True,timeout=240)
   test={'language':lang,'exit':r.returncode,'seconds':round(time.monotonic()-start,2),'text':r.stdout.strip()};(out/(m['id']+'-'+lang+'.log')).write_text(r.stderr)
  except subprocess.TimeoutExpired:test={'language':lang,'exit':'timeout','seconds':240}
  row['tests'].append(test);print(m['id'],test,flush=True)
 results.append(row);(out/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
 print('INTEGRITY',m['id'],row['integrity'],flush=True)
