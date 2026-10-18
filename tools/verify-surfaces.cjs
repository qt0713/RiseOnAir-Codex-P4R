// Isolated regression fixture; never connects Playwright to a live Codex app.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
(async()=>{
 const root=path.resolve(__dirname,'..'),engine=process.argv[2];
 if(!engine)throw Error('Pass a locally patched Dream Skin engine directory.');
 const {loadPayload}=await import(pathToFileURL(path.resolve(engine,'scripts/injector.mjs')).href);
 const {payload}=await loadPayload(path.join(root,'src/theme'));
 const browser=await chromium.launch({executablePath:process.env.CHROME_PATH||'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 const page=await browser.newPage();const errors=[],results=[];
 page.on('pageerror',e=>errors.push(e.message));
 for(const scheme of ['light','dark'])for(const width of [390,1280]){
  await page.emulateMedia({colorScheme:scheme});await page.setViewportSize({width,height:900});
  await page.setContent(`<!doctype html><html style="color-scheme:${scheme}"><head><style>body{margin:0;font:16px system-ui}aside{display:none}main{min-height:100vh}.thread-scroll-container{padding:24px;max-width:760px;margin:auto}h1{font-size:24px}.fixture{margin:16px 0}p{line-height:1.7}</style></head><body><aside class="app-shell-left-panel"></aside><main class="main-surface"><header class="app-header-tint"></header><div class="thread-scroll-container"><h1>RISE ON AIR · 半透明消息表面</h1><section class="fixture"><h2>正在处理</h2><div id="reasoning" data-response-annotation-conversation="fixture" data-response-annotation-target="fixture"><p>正在整理主题样式。思考过程与最终回复使用同一层半透明底色，背景图仍可见，文字保持清晰。</p></div></section><section class="fixture"><h2>最终回复</h2><div id="final" data-local-conversation-final-assistant="true"><div id="nested" data-response-annotation-conversation="fixture" data-response-annotation-target="fixture"><p>主题样式已统一。内容完成后，内层背景清空，避免多层透明底色叠加。</p></div></div></section><div class="composer-surface-chrome"><div contenteditable="true">输入区域</div></div></div></main></body></html>`);
  await page.evaluate(payload);
  await page.waitForFunction(()=>document.querySelector('#final').dataset.dsPart==='message');
  const state=await page.evaluate(()=>{
   const read=id=>{const s=getComputedStyle(document.getElementById(id));const c=new OffscreenCanvas(1,1).getContext('2d');c.fillStyle=s.backgroundColor;c.fillRect(0,0,1,1);return {background:s.backgroundColor,rgba:[...c.getImageData(0,0,1,1).data],image:s.backgroundImage,blur:s.backdropFilter,opacity:s.opacity}};
   return {reasoning:read('reasoning'),final:read('final'),nested:read('nested'),overflow:document.documentElement.scrollWidth>innerWidth};
  });
  if(state.reasoning.rgba.some((v,i)=>Math.abs(v-state.final.rgba[i])>1)||state.reasoning.rgba[3]!==179||state.reasoning.image!=='none'||state.reasoning.blur!=='none'||state.nested.rgba[3]!==0||state.reasoning.opacity!=='1'||state.overflow)throw Error(JSON.stringify({scheme,width,state}));
  await page.locator('#reasoning').evaluate(el=>{el.hidden=true;el.hidden=false});
  if(scheme==='light'&&width===1280)await page.screenshot({path:path.join(root,'docs/reasoning-surfaces.png')});
  results.push({scheme,width,...state});
 }
 await browser.close();if(errors.length)throw Error(errors.join('\n'));
 fs.writeFileSync(path.join(root,'.local-evidence/surface-tests.json'),JSON.stringify({results,errors},null,2));
 console.log(JSON.stringify({passed:results.length,errors}));
})().catch(e=>{console.error(e);process.exit(1)});
