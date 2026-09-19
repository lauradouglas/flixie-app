const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');const sharp=require('sharp');
const root=path.resolve(__dirname,'..');
function all(p){return fs.readdirSync(p,{withFileTypes:true}).flatMap(d=>d.isDirectory()?all(path.join(p,d.name)):[path.join(p,d.name)]);}
(async()=>{
 let count=0;
 for(const f of all(root).filter(f=>f.endsWith('.png'))){
  const m=await sharp(f).metadata();assert.equal(m.format,'png');
  if(f.includes('/apple/') && !f.includes('/icon-composer-sources/foreground-'))assert.equal(m.hasAlpha,false,f);
  if(f.includes('/transparent/')){assert.equal(m.hasAlpha,true,f);const s=await sharp(f).stats();assert.equal(s.channels[3].min,0);assert.equal(s.channels[3].max,255);}
  count++;
 }
 for(const folder of ['apple/AppIcon.appiconset','apple/legacy/AppIcon.appiconset']){
  const catalog=JSON.parse(fs.readFileSync(path.join(root,folder,'Contents.json')));
  for(const a of catalog.images){const m=await sharp(path.join(root,folder,a.filename)).metadata();const expected=Number(a.size.split('x')[0])*Number((a.scale||'1x').replace('x',''));assert.equal(m.width,expected);assert.equal(m.height,expected);}
 }
 const play=await sharp(path.join(root,'stores/google-play-512.png')).metadata();assert.equal(play.width,512);assert.equal(play.height,512);assert.equal(play.channels,4);assert(fs.statSync(path.join(root,'stores/google-play-512.png')).size<1024*1024);
 const app=await sharp(path.join(root,'stores/apple-app-store-1024.png')).metadata();assert.equal(app.width,1024);assert.equal(app.height,1024);assert.equal(app.hasAlpha,false);
 // Bounding rectangle corners of both paths fit within the conservative 66dp circle.
 for(const x of [24,78])for(const y of [18,82])assert(Math.hypot(x*.76+15.24-54,y*.76+16-54)<33);
 const {data,info}=await sharp(path.join(root,'android/sources/adaptive-foreground-432.png')).raw().toBuffer({resolveWithObject:true});
 let outside=0;for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>0 && Math.hypot((x+.5)/4-54,(y+.5)/4-54)>33)outside++;
 assert.equal(outside,0,'Adaptive alpha must stay inside safe circle');
 const result={pngFilesChecked:count,appleCatalogDimensions:'pass',appleNoAlpha:'pass',transparentMasters:'pass',googlePlaySizeChannelsFileLimit:'pass',android66dpSafeCircle:'pass'};
 fs.writeFileSync(path.join(root,'validation.json'),JSON.stringify(result,null,2));console.log(result);
})();
