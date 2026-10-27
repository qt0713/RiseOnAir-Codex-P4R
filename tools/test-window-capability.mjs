import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {supportsWindowResume,inspectArchive} from '../src/runtime/window-capability.mjs';
const handler='if(o.type===`open-current-main-window`||o.type===`open-in-main-window`){let e=o.type===`open-current-main-window`?null:o.path;r&&(o.stealFocus===!0?h({focusComposer:o.focusComposer,stealFocus:!0}):(r.isMinimized()&&r.restore(),r.show(),r.focus()));return}';
test('handler contract survives quote and local variable changes',()=>{
 for(const quote of ['"',"'",'`'])assert.equal(supportsWindowResume(handler.replaceAll('`',quote)),true);
 assert.equal(supportsWindowResume(handler.replaceAll('r.','windowRef.')),true);
});
test('changed or unrelated protocols are rejected',()=>{
 for(const text of [handler.replace('r.restore()','r.close()'),handler.replace('r.show()','other.show()'),handler.replace('open-current-main-window','changed-command'),handler.replace('r.focus()','r.hide()'),'case`open-current-main-window`:break;'+handler.slice(handler.indexOf('r&&'))])assert.equal(supportsWindowResume(text),false);
});
test('bounded ASAR reader checks current content and rejects malformed archives',()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'rise-capability-'));
 try{
  const file=path.join(folder,'app.asar');
  const source=Buffer.from(handler);
  const index=Buffer.from(JSON.stringify({files:{'.vite':{files:{build:{files:{'main-future.js':{size:source.length,offset:'0'}}}}}}}));
  const header=Buffer.alloc(index.length+8);header.writeUInt32LE(index.length,4);index.copy(header,8);
  const prefix=Buffer.alloc(8);prefix.writeUInt32LE(header.length,4);
  fs.writeFileSync(file,Buffer.concat([prefix,header,source]));assert.equal(inspectArchive(file).resume,true);
  fs.writeFileSync(file,Buffer.from([1,2,3]));assert.throws(()=>inspectArchive(file));
  prefix.writeUInt32LE(0xffffffff,4);fs.writeFileSync(file,prefix);assert.throws(()=>inspectArchive(file));
 }finally{fs.rmSync(folder,{recursive:true,force:true});}
});
