import assert from 'node:assert/strict';
import vm from 'node:vm';
import {verifyFirstPaint} from '../src/runtime/first-paint.mjs';
const expected = ['p4r-rise-on-air', 'revision-1', 'version-1'];
async function check(change = () => {}) {
  const sheet = {}, node = {
    isConnected: true, closest: () => null,
    getBoundingClientRect: () => ({width: 500, height: 400, left: 0, top: 0, right: 500, bottom: 400}),
    checkVisibility: () => true,
  };
  const attributes = {'data-dream-skin':'active', 'data-dream-art-ready':'true'};
  const runtime = {themeId:expected[0],revision:expected[1],version:expected[2],
    styleMode:'adopted',styleSheet:sheet,artUrl:'data:image/png;base64,test',scope:{level:'L1',missingL1:[]}};
  const context = {window:{__CODEX_DREAM_SKIN_STATE__:runtime},innerWidth:1280,innerHeight:720,
    document:{documentElement:{getAttribute:key=>attributes[key]},body:{},
      adoptedStyleSheets:[sheet], getElementById:()=>null,
      visibilityState:'visible',hidden:false,querySelectorAll:()=>[node]},
    getComputedStyle:()=>({display:'block',visibility:'visible',opacity:'1',backgroundImage:'url("data:image/png;base64,test")'})};
  change(context, runtime, attributes, node);
  return verifyFirstPaint({evaluate:expression=>vm.runInNewContext(expression,context)},...expected);
}
assert.equal((await check()).pass, true);
assert.equal((await check((c,r)=>{
  r.artUrl='blob:app://rise-art';
  c.getComputedStyle=(node,pseudo)=>({display:'block',visibility:'visible',opacity:'1',
    content:pseudo ? '""' : 'normal',backgroundImage:pseudo === '::before' ? 'url("blob:app://rise-art")' : 'none'});
})).pass, true);
for (const change of [
  (c,r)=>{r.themeId='wrong';}, (c,r)=>{r.revision='stale';},
  (c,r)=>{r.version='stale';}, (c,r)=>{r.styleSheet={};},
  (c,r,a)=>{a['data-dream-art-ready']='false';},
  c=>{c.getComputedStyle=()=>({backgroundImage:'none'});},
  c=>{c.document.visibilityState='hidden';}, c=>{c.document.hidden=true;},
  c=>{c.innerWidth=0;}, c=>{c.document.querySelectorAll=()=>[];},
  (c,r)=>{r.scope.missingL1=['composer'];},
  (c,r,a,n)=>{n.checkVisibility=()=>false;},
]) assert.equal((await check(change)).pass, false);
console.log('First-paint proof: valid render passes; 12 incomplete/stale/hidden states rejected.');
