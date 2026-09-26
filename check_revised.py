import re,json,sys
F=sys.argv[1]
rev=open(F,encoding='utf-8-sig').read()
M=json.load(open(__import__('os').environ.get('MAP','/tmp/mw/text_export/_map.json'),encoding='utf8'))
ents={}; order=[]
for blk in re.split(r'\n(?=\[[A-Za-z0-9_.#-]+\] - \[)', rev):
    h=re.match(r'\[([^\]]+)\] - \[',blk)
    if not h or 'ข้อความ (Text):' not in blk: continue
    t=blk.split('ข้อความ (Text):',1)[1]
    t=t.split('\n----------------------------------------')[0].strip('\n')
    ents[h.group(1)]=t; order.append(h.group(1))
exp=[k for k in M if k.startswith(('STORY.','PROLOGUE.','SRC.story','SRC.openStoryLog'))] if '01' in F else None
print('entries',len(ents))
if exp:
    print('missing',[k for k in exp if k not in ents][:20], len([k for k in exp if k not in ents]))
print('unknown',[k for k in ents if k not in M][:20])
chg=[k for k in ents if k in M and ents[k].strip()!=M[k]['text'].strip()]
print('changed',len(chg))
iss={'bold':[], 'boldodd':[], 'num':[], 'ph':[], 'long':[], 'emoji':[], 'nl':[], 'tag':[]}
EMO=re.compile('[\U0001F300-\U0001FAFF☀-➿]')
for k in chg:
    o=M[k]['text']; t=ents[k]
    if o.count('**') and not t.count('**'): iss['bold'].append(k)
    if t.count('**')%2: iss['boldodd'].append(k)
    if sorted(re.findall(r'\d+',o))!=sorted(re.findall(r'\d+',t)): iss['num'].append((k,re.findall(r'\d+',o),re.findall(r'\d+',t)))
    if sorted(re.findall(r'\{[^}]*\}',o))!=sorted(re.findall(r'\{[^}]*\}',t)): iss['ph'].append((k,re.findall(r'\{[^}]*\}',o),re.findall(r'\{[^}]*\}',t)))
    r=len(t)/max(1,len(o))
    if r>1.35 and len(o)>30: iss['long'].append((k,round(r,2),len(o),len(t)))
    if sorted(EMO.findall(o))!=sorted(EMO.findall(t)): iss['emoji'].append((k,EMO.findall(o),EMO.findall(t)))
    if o.count('\n')!=t.count('\n'): iss['nl'].append((k,o.count('\n'),t.count('\n')))
    if sorted(re.findall(r'<[^>]*>',o))!=sorted(re.findall(r'<[^>]*>',t)) or re.match(r'^\[[a-z]+\]',o) and not t.startswith(re.match(r'^\[[a-z]+\]',o).group(0)): iss['tag'].append(k)
for k,v in iss.items(): print(k,len(v), v[:12])
json.dump({'ents':ents,'changed':chg},open('/tmp/rev_parsed.json','w'),ensure_ascii=False)
