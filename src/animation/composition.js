/* HyperFrames WAAPI: all visual state is a pure function of document time. */
(()=>{
const params=new URLSearchParams(location.search);const requested=params.get('mode')||document.getElementById('root').dataset.mode||'showcase';
const mode=['showcase','daily','reduced'].includes(requested)?requested:'showcase';
const duration={showcase:3.2,daily:1.6,reduced:1.2}[mode];
const root=document.getElementById('root');root.dataset.duration=duration;
document.querySelector('.clip').dataset.duration=duration;
const anims=[];const ease='cubic-bezier(.22,.7,.18,1)';
function a(sel,keys,start,len,easing=ease){document.querySelectorAll(sel).forEach(el=>{const an=el.animate(keys,{delay:start*1000,duration:len*1000,fill:'both',easing,iterations:1});an.pause();an.currentTime=0;anims.push(an)})}
if(mode==='reduced'){
 a('.workbench',[{opacity:0},{opacity:1}],.96,.24,'linear');
 a('.signal',[{opacity:0},{opacity:0}],0,duration);
 a('.scanlines',[{opacity:0},{opacity:0}],0,duration);
 a('.codex-block',[{opacity:0},{opacity:0}],0,duration);
 a('.intro',[{opacity:0},{opacity:1,offset:.18},{opacity:1,offset:.8},{opacity:0}],0,duration,'linear');
}else{
 const daily=mode==='daily';
 const cue=daily?{open:.03,reveal:.14,revealDur:.23,name:.25,nameDur:.2,hold:.57,codex:.85,exit:1.29,exitDur:.31}:{open:.08,reveal:.30,revealDur:.46,name:.64,nameDur:.38,hold:1.12,codex:1.72,exit:2.62,exitDur:.58};
 a('.signal span',[{transform:'scaleX(0)',opacity:0},{transform:'scaleX(1)',opacity:1,offset:.32},{transform:'scaleX(1.8)',opacity:0}],0,daily?.20:.34);
 a('.tv',[{transform:'scale(.65,.005)',opacity:0},{transform:'scale(.97,.008)',opacity:1,offset:.18},{transform:'scale(1)',opacity:1}],cue.open,daily?.24:.45);
 a('.portrait-reveal',[{clipPath:'inset(0 100% 0 0)',transform:'translateX(-20px)'},{clipPath:'inset(0 0% 0 0)',transform:'translateX(0px)'}],cue.reveal,cue.revealDur);
 a('.pink-disc',[{transform:'translateX(-80px) scale(.9)'},{transform:'translateX(0px) scale(1)'}],cue.reveal,cue.revealDur);
 a('.diagonal',[{opacity:0},{opacity:.28}],cue.reveal,cue.revealDur);
 a('.channel',[{opacity:0},{opacity:1}],cue.reveal+.05,daily?.16:.26);
 const titleEnd=cue.codex+(daily?.04:.15);
 a('.title-block',[{opacity:0,transform:'translate(24px,0px)',offset:0},{opacity:1,transform:'translate(0px,0px)',offset:cue.nameDur/(titleEnd-cue.name)},{opacity:1,transform:'translate(0px,0px)',offset:(cue.codex-.1-cue.name)/(titleEnd-cue.name)},{opacity:0,transform:'translate(0px,-12px)',offset:1}],cue.name,titleEnd-cue.name,'linear');
 a('.name-rule',[{transform:'scaleX(0)'},{transform:'scaleX(1)'}],cue.name+.08,cue.nameDur);
 a('.footnote,.tv-corner',[{opacity:0},{opacity:1}],cue.name,cue.nameDur);
 a('.portrait-greet',[{transform:'rotate(0deg)'},{transform:'rotate(-.65deg)',offset:.45},{transform:'rotate(0deg)'}],cue.hold,daily?.32:.60);
 a('.scanlines',[{opacity:0},{opacity:.18,offset:.18},{opacity:0}],0,daily?.27:.48,'linear');
 a('.codex-block',[{opacity:0,transform:'translateY(12px)'},{opacity:1,transform:'translateY(0px)'}],cue.codex,daily?.18:.30);
 a('.cursor',[{transform:'scaleY(.04)'},{transform:'scaleY(1)'}],cue.codex,daily?.15:.25);
 a('.intro',[{opacity:1},{opacity:0}],cue.exit,cue.exitDur,'cubic-bezier(.4,0,.8,1)');
 a('.workbench',[{opacity:0},{opacity:1}],cue.exit,cue.exitDur,'linear');
}
window.rise={mode,duration,animations:anims,seek(t){const bounded=Math.max(0,Math.min(duration,t));anims.forEach(an=>{an.currentTime=bounded*1000;an.pause()});return bounded}};
// Export retains its authored 16:9 canvas. Interactive hosts opt in to reflow;
// changing layout never changes the paused animation's current time.
function fit(){const responsive=params.has('responsive');const ratio=innerWidth/innerHeight;const layout=responsive?(ratio<1?'portrait':ratio<1.6?'compact':'wide'):'wide';const w=layout==='portrait'?720:layout==='compact'?1024:1280;const h=layout==='portrait'?Math.max(1000,Math.min(1600,w/ratio)):layout==='compact'?Math.max(720,Math.min(1024,w/ratio)):720;root.dataset.layout=layout;const s=Math.min(innerWidth/w,innerHeight/h);root.style.width=`${w}px`;root.style.height=`${h}px`;root.style.transformOrigin='top left';root.style.transform=`scale(${s})`;root.style.marginLeft=`${(innerWidth-w*s)/2}px`;root.style.marginTop=`${(innerHeight-h*s)/2}px`}
addEventListener('resize',fit);fit();window.rise.seek(0);
})();
