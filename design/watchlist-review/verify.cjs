const {chromium}=require('/Users/lauradouglas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
const b=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
const p=await b.newPage({viewport:{width:1200,height:1080},deviceScaleFactor:1.5});
await p.goto('file://'+__dirname+'/mockup.html');
await p.screenshot({path:__dirname+'/mockup-board.png',fullPage:true});
await p.setViewportSize({width:390,height:844});await p.screenshot({path:__dirname+'/mockup-mobile.png',fullPage:true});
await p.getByRole('button',{name:/3 friends watched/}).click();await p.screenshot({path:__dirname+'/friend-ratings.png'});await p.getByRole('button',{name:'Close',exact:true}).click();
await p.getByRole('button',{name:'Shows',exact:true}).click();console.log('Shows count:',await p.locator('#count').innerText());
await p.getByRole('button',{name:'On my services',exact:true}).click();console.log('Subscribed shows:',await p.locator('#count').innerText());
await p.locator('#searchbox').fill('no match');console.log('Empty state:',await p.locator('.empty').innerText());
await p.getByRole('button',{name:'Clear filters',exact:true}).click();
await p.setViewportSize({width:320,height:690});console.log('320 overflow:',await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth));await p.screenshot({path:__dirname+'/mockup-small.png'});
await p.setViewportSize({width:844,height:390});console.log('Landscape overflow:',await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth));
await p.setViewportSize({width:768,height:1024});console.log('Tablet overflow:',await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth));
await p.addStyleTag({content:'.phone{font-size:200%}.phone h1{font-size:3.75rem}.phone h2{font-size:2.5rem}.phone .metadata,.phone .socialText,.phone .provider{font-size:1.5rem}'});
await p.setViewportSize({width:390,height:844});console.log('Large text horizontal overflow:',await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth));
}finally{await b.close()}
})();
