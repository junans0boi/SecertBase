import sys,os
M=os.path.dirname(os.path.abspath(__file__))
order=['system','auth','pairing','home','moment','map','base','us','care','more','shop']
only=sys.argv[1:]
shell=open(f'{M}/shell.html').read()
ds=open(f'{M}/ds.css').read()
shell=shell.replace('</style>',ds+'\n</style>',1)
parts=[]
for g in order:
    if only and g not in only: continue
    p=f'{M}/tabs/{g}.html'
    if os.path.exists(p): parts.append(open(p).read())
out=shell.replace('<!--GAMES-->','\n'.join(parts))
name='index.html' if not only else 'preview-'+'-'.join(only)+'.html'
open(f'{M}/{name}','w').write(out); print(name,len(out))
