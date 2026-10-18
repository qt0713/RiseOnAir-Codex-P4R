const post=message=>window.webkit.messageHandlers.rise.postMessage(message);
const mute=document.getElementById('mute');
let audio,api,running=false,muted=false,voiceStarted=false,start=0,raf=0,captured=false;
function updateMute(){mute.textContent=muted?'开启语音':'静音';if(audio)audio.muted=muted}
mute.onclick=()=>{muted=!muted;updateMute()};
function stop(){running=false;cancelAnimationFrame(raf);audio?.pause()}
document.getElementById('skip').onclick=()=>{stop();post('skip')};
document.getElementById('replay').onclick=()=>begin();
document.addEventListener('keydown',e=>{if(e.key==='Escape'){stop();post('skip')}if(e.key.toLowerCase()==='m')mute.click()});
function begin(){stop();api.seek(0);voiceStarted=false;captured=false;start=performance.now();running=true;post('playing');raf=requestAnimationFrame(tick)}
function tick(now){if(!running)return;const t=Math.min(api.duration,(now-start)/1000);api.seek(t);if(!voiceStarted&&t>=.68){voiceStarted=true;audio.currentTime=Math.max(0,t-.68);audio.play().then(()=>post('voice-playing')).catch(e=>post('voice-unavailable '+e.name))}if(!captured&&t>=1.4){captured=true;post('capture')}if(t>=api.duration){stop();post('ended');return}raf=requestAnimationFrame(tick)}
window.riseHost={start(options){muted=options.muted;document.getElementById('replay').hidden=!options.preview;updateMute();begin()},waiting(failed){stop();api?.seek(2.35);const w=document.getElementById('wait');w.hidden=false;w.textContent=failed?'主题暂未就绪，可从菜单重试或查看日志。':'正在打开 Codex 并验证主题…'}};
window.addEventListener('load',async()=>{try{await document.fonts.ready;await Promise.all([...document.images].map(im=>im.decode()));api=window.rise;audio=document.getElementById('rise-greeting');audio.volume=.8;audio.addEventListener('loadedmetadata',()=>post('audio-loaded'),{once:true});audio.load();post('metadata '+api.duration);post('ready')}catch(e){post('error '+e.message)}});
