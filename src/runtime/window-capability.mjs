// Read-only compatibility probe for the registered official application.
// Never evaluates vendor code. Unknown handler shapes remain unsupported.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
export function supportsWindowResume(source) {
  const start=/if\(([\w$]+)\.type===(["'`])open-current-main-window\2\|\|\1\.type===(["'`])open-in-main-window\3\)\{/g;
  for (const match of source.matchAll(start)) {
    const tail=source.slice(match.index,match.index+1800);
    const end=tail.indexOf('return}');
    if(end<0)continue;
    const branch=tail.slice(0,end);
    // Same reviewed false-stealFocus branch: restore, show, focus the SAME
    // window. Variable names and bundler quote style may change across builds.
    if(/\.stealFocus===!0\?[\w$]+\(\{focusComposer:[\w$]+\.focusComposer,stealFocus:!0\}\):\(([\w$]+)\.isMinimized\(\)&&\1\.restore\(\),\1\.show\(\),\1\.focus\(\)\)/.test(branch))return true;
  }
  return false;
}
export function inspectArchive(file) {
  const fd=fs.openSync(file,'r');
  try {
    const stat=fs.fstatSync(fd),head=Buffer.alloc(8);
    if(fs.readSync(fd,head,0,8,0)!==8)throw Error('Truncated ASAR');
    const size=head.readUInt32LE(4);
    if(size<8||size>16*1024*1024||8+size>stat.size)throw Error('Invalid ASAR header size');
    const header=Buffer.alloc(size);
    if(fs.readSync(fd,header,0,size,8)!==size)throw Error('Truncated ASAR index');
    const length=header.readUInt32LE(4);
    if(length>size-8)throw Error('Invalid ASAR index');
    const files=JSON.parse(header.subarray(8,8+length).toString()).files?.['.vite']?.files?.build?.files;
    const names=Object.keys(files||{}).filter(n=>/^main(?:-[\w-]+)?\.js$/.test(n));
    if(names.length!==1)throw Error('No unique main bundle');
    const entry=files[names[0]],offset=8+size+Number(entry.offset);
    if(entry.unpacked||entry.link||!Number.isSafeInteger(offset)||!Number.isSafeInteger(entry.size)||entry.size<1||entry.size>32*1024*1024||offset<8+size||offset+entry.size>stat.size)throw Error('Invalid main bundle bounds');
    const content=Buffer.alloc(entry.size);
    if(fs.readSync(fd,content,0,entry.size,offset)!==entry.size)throw Error('Truncated main bundle');
    const after=fs.fstatSync(fd);
    if(after.size!==stat.size||after.mtimeMs!==stat.mtimeMs)throw Error('Application changed during probe');
    return {schema:1,resume:supportsWindowResume(content.toString()),method:'reviewed-handler-shape',bundle:names[0]};
  }finally{fs.closeSync(fd);}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
  try{console.log(JSON.stringify(inspectArchive(process.argv[2])));}catch(error){console.log(JSON.stringify({schema:1,resume:false,reason:error.message}));}
}
