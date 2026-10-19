// Called only after the wrapper verifies the listener owner and saved Browser ID.
const [portText,browserId]=process.argv.slice(2),port=Number(portText);
if(!Number.isInteger(port)||port<1||port>65535||!/^[\w.-]{1,200}$/.test(browserId))throw Error('Invalid identity');
async function json(path){const r=await fetch(`http://127.0.0.1:${port}${path}`,{redirect:'error',signal:AbortSignal.timeout(2500)});if(!r.ok)throw Error('Endpoint unavailable');return r.json();}
function socketUrl(value,kind,id){const u=new URL(value);if(!['ws:'].includes(u.protocol)||!['127.0.0.1','localhost','[::1]'].includes(u.hostname)||Number(u.port)!==port||u.pathname!==`/devtools/${kind}/${id}`||u.username||u.password||u.search||u.hash)throw Error('Invalid WebSocket');return u.href;}
const version=await json('/json/version');socketUrl(version.webSocketDebuggerUrl,'browser',browserId);
const targets=await json('/json/list');
const main=targets.filter(t=>{try{const u=new URL(t.url);return t.type==='page'&&u.protocol==='app:'&&u.pathname==='/index.html'&&!u.search&&!u.hash;}catch{return false;}});
if(main.length!==1)throw Error('No unique main renderer; auxiliary windows are excluded');
const target=main[0];if(!/^[\w.-]{1,200}$/.test(target.id))throw Error('Invalid target');
const ws=new WebSocket(socketUrl(target.webSocketDebuggerUrl,'page',target.id));
const geometry=await new Promise((resolve,reject)=>{
 const timeout=setTimeout(()=>{ws.close();reject(Error('Renderer timeout'));},5000);
 ws.onopen=()=>ws.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{expression:'JSON.stringify({x:screenX,y:screenY,width:outerWidth,height:outerHeight,dpr:devicePixelRatio})',returnByValue:true}}));
 ws.onerror=()=>{clearTimeout(timeout);reject(Error('Renderer connection failed'));};
 ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id!==1)return;clearTimeout(timeout);ws.close();if(m.error||m.result?.exceptionDetails){reject(Error('Window metadata unavailable'));return;}try{resolve(JSON.parse(m.result.result.value));}catch{reject(Error('Invalid metadata'));}};
});
for(const key of ['x','y','width','height','dpr'])if(!Number.isFinite(geometry[key]))throw Error('Invalid window geometry');
socketUrl((await json('/json/version')).webSocketDebuggerUrl,'browser',browserId);
console.log(JSON.stringify(geometry));
