const post=message=>window.webkit.messageHandlers.rise.postMessage(message);
const mute=document.getElementById('mute');
let audio,api,muted=false,clock=[],generation=0,options={};
function updateMute(){mute.textContent=muted?'开启语音':'静音';if(audio)audio.muted=muted}
mute.onclick=()=>{muted=!muted;updateMute()};
function stop(){generation++;clock.forEach(clearTimeout);clock=[];audio?.pause();api?.animations.forEach(a=>a.pause())}
document.getElementById('skip').onclick=()=>{stop();post('skip')};
document.getElementById('replay').onclick=()=>begin();
document.addEventListener('keydown',e=>{if(e.key==='Escape'){stop();post('skip')}if(e.key.toLowerCase()==='m')mute.click()});
function begin(){
  stop();const run=generation;
  document.getElementById('wait').hidden=true;
  api.seek(0);
  // Let WebKit advance the authored animations together; no per-frame seeking.
  api.animations.forEach(a=>a.play());
  post('playing');
  const cue=(ms,fn)=>clock.push(setTimeout(()=>{if(run===generation)fn()},ms));
  cue(680,()=>{audio.currentTime=0;audio.play().then(()=>post('voice-playing')).catch(e=>post('voice-unavailable '+e.name))});
  if(options.capture)cue(1400,()=>post('capture'));
  cue(api.duration*1000,()=>{stop();api.seek(api.duration);post('ended')});
}
window.riseHost={start(value){options=value;muted=value.muted;document.getElementById('replay').hidden=!value.preview;updateMute();begin()},waiting(failed){stop();api?.seek(2.35);const w=document.getElementById('wait');w.hidden=false;w.textContent=failed?'主题暂未就绪，可从菜单重试或查看日志。':'正在打开 Codex 并验证主题…'}};
window.addEventListener('load',async()=>{try{
  await Promise.all([document.fonts.ready,...[...document.images].map(im=>im.decode())]);
  api=window.rise;audio=document.getElementById('rise-greeting');audio.volume=.8;
  if(audio.readyState>=1)post('audio-loaded');else audio.addEventListener('loadedmetadata',()=>post('audio-loaded'),{once:true});
  post('metadata '+api.duration);post('ready')
}catch(e){post('error '+e.message)}});
