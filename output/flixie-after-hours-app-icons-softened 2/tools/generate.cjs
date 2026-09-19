// Softened After Hours F: original proportions, 3-unit rounded corners. Requires sharp 0.34+.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const paths = ["M27 82 Q24 82 24 79 L24 21 Q24 18 27 18 L75 18 Q78 18 78 21 L78 31 Q78 34 75 34 L45 34 Q42 34 42 37 L42 43 Q42 46 45 46 L65 46 Q68 46 68 49 L68 59 Q68 62 65 62 L45 62 Q42 62 42 65 L42 79 Q42 82 39 82 Z", "M54 73 Q54 70 57 70 L75 70 Q78 70 78 73 L78 79 Q78 82 75 82 L57 82 Q54 82 54 79 Z"];
const colours = {lilac:'#B9A0FF', midnight:'#120A24', white:'#FFFFFF', bone:'#F3F0E9'};
function write(name, data) { const p=path.join(root,name);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,data); }
function mark(colour,transform='translate(-1 0)') {return `<g fill="${colour}" transform="${transform}">${paths.map(d=>`<path d="${d}"/>`).join('')}</g>`;}
function svg(body,size=1024,view=100) {return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${view} ${view}">${body}</svg>`;}
function icon(fg=colours.lilac,bg=colours.midnight) {return svg(`<rect width="100" height="100" fill="${bg}"/>`+mark(fg));}
async function png(name,source,size,alpha=true) { let p=sharp(Buffer.from(source)).resize(size,size).toColourspace('srgb'); p=alpha?p.ensureAlpha():p.removeAlpha();write(name,await p.png({compressionLevel:9,palette:false}).toBuffer()); }
function vector(colour,view=108,scale=.76,tx=15.24,ty=16) {return `<?xml version="1.0" encoding="utf-8"?>\n<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="${view}dp" android:height="${view}dp" android:viewportWidth="${view}" android:viewportHeight="${view}"><group android:scaleX="${scale}" android:scaleY="${scale}" android:translateX="${tx}" android:translateY="${ty}">${paths.map(d=>`<path android:fillColor="${colour}" android:pathData="${d}"/>`).join('')}</group></vector>\n`;}
(async()=>{
 for(const [name,c] of Object.entries(colours)){
  const source=svg(mark(c));write(`masters/f-${name}-transparent.svg`,source);
  for(const size of [256,512,1024,2048])await png(`transparent/f-${name}-${size}.png`,source,size);
 }
 const def=icon(),dark=icon(colours.lilac,'#0A0616'),tinted=icon('#FFFFFF','#000000');
 write('masters/app-icon.svg',def);
 await png('stores/apple-app-store-1024.png',def,1024,false);
 await png('stores/google-play-512.png',def,512,true);
 const images=[];
 for(const [name,source,appearance] of [['default',def,null],['dark',dark,'dark'],['tinted',tinted,'tinted']]){
  await png(`apple/AppIcon.appiconset/after-hours-${name}-1024.png`,source,1024,false);
  const item={filename:`after-hours-${name}-1024.png`,idiom:'universal',platform:'ios',size:'1024x1024'};
  if(appearance)item.appearances=[{appearance:'luminosity',value:appearance}];images.push(item);
 }
 write('apple/AppIcon.appiconset/Contents.json',JSON.stringify({images,info:{author:'xcode',version:1}},null,2));
 // Classic, all-slot alternative for projects using older Xcode versions.
 const legacy=[];
 for(const [idiom,points,scales] of [['iphone',20,[2,3]],['iphone',29,[1,2,3]],['iphone',40,[2,3]],['iphone',60,[2,3]],['ipad',20,[1,2]],['ipad',29,[1,2]],['ipad',40,[1,2]],['ipad',76,[1,2]],['ipad',83.5,[2]],['ios-marketing',1024,[1]]]) {
  for(const scale of scales){const filename=`Icon-App-${points}x${points}@${scale}x.png`;await png(`apple/legacy/AppIcon.appiconset/${filename}`,def,Math.round(points*scale),false);legacy.push({size:`${points}x${points}`,idiom,filename,scale:`${scale}x`});}
 }
 write('apple/legacy/AppIcon.appiconset/Contents.json',JSON.stringify({images:legacy,info:{author:'xcode',version:1}},null,2));
 write('apple/icon-composer-sources/foreground.svg',svg(mark(colours.lilac)));
 await png('apple/icon-composer-sources/foreground-1024.png',svg(mark(colours.lilac)),1024);
 await png('apple/icon-composer-sources/background-1024.png',svg('<rect width="100" height="100" fill="#120A24"/>'),1024,false);
 const adaptive=svg(mark(colours.lilac,'translate(15.24 16) scale(.76)'),1080,108);
 const mono=svg(mark('#FFFFFF','translate(15.24 16) scale(.76)'),1080,108);
 write('android/sources/adaptive-foreground.svg',adaptive);write('android/sources/adaptive-monochrome.svg',mono);
 await png('android/sources/adaptive-foreground-432.png',adaptive,432);
 await png('android/sources/adaptive-monochrome-432.png',mono,432);
 await png('android/sources/adaptive-background-432.png',svg('<rect width="108" height="108" fill="#120A24"/>',432,108),432,false);
 write('android/res/drawable/after_hours_foreground.xml',vector(colours.lilac));
 write('android/res/drawable/after_hours_monochrome.xml',vector('#FFFFFF'));
 write('android/res/drawable/ic_stat_flixie.xml',vector('#FFFFFF',24,.28125,-2.34375,-2.0625));
 write('android/res/values/after_hours_colors.xml','<?xml version="1.0" encoding="utf-8"?>\n<resources><color name="after_hours_background">#120A24</color></resources>\n');
 for(const api of [26,33]){
  const body=`<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/after_hours_background"/><foreground android:drawable="@drawable/after_hours_foreground"/>${api===33?'<monochrome android:drawable="@drawable/after_hours_monochrome"/>':''}</adaptive-icon>\n`;
  for(const name of ['launcher_icon','launcher_icon_round'])write(`android/res/mipmap-anydpi-v${api}/${name}.xml`,body);
 }
 for(const [density,size] of [['ldpi',36],['mdpi',48],['hdpi',72],['xhdpi',96],['xxhdpi',144],['xxxhdpi',192]]){
  await png(`android/res/mipmap-${density}/launcher_icon.png`,def,size,false);
  const round=svg(`<defs><clipPath id="circle"><circle cx="50" cy="50" r="50"/></clipPath></defs><g clip-path="url(#circle)"><rect width="100" height="100" fill="#120A24"/>${mark(colours.lilac)}</g>`);
  await png(`android/res/mipmap-${density}/launcher_icon_round.png`,round,size,true);
 }
 // Review board: simulated OS masks, not baked into exported app/store files.
 let board='<rect width="1440" height="1050" fill="#F3F0E9"/>';
 const text=(x,y,t,s=22,c='#120A24')=>`<text x="${x}" y="${y}" font-family="Helvetica,Arial,sans-serif" font-size="${s}" fill="${c}">${t.replaceAll('&','&amp;')}</text>`;
 board+=text(60,66,'FLIXIE / AFTER HOURS — SOFTENED',25)+text(60,122,'App icon master & platform exports',42);
 const tile=(x,y,size,fg,bg,mask)=>`<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 100 100"><defs><clipPath id="m${x}${y}">${mask==='circle'?'<circle cx="50" cy="50" r="50"/>':'<rect width="100" height="100" rx="22"/>'}</clipPath></defs><g clip-path="url(#m${x}${y})"><rect width="100" height="100" fill="${bg}"/>${mark(fg)}</g></svg>`;
 board+=tile(60,190,270,colours.lilac,colours.midnight,'square')+tile(415,190,270,colours.lilac,'#0A0616','square')+tile(770,190,270,'#DCCEFF','#392652','circle');
 board+=text(60,503,'Apple / default')+text(415,503,'Apple / dark')+text(770,503,'Android / themed example');
 // Transparent artwork displayed on a checkerboard; PNG files retain alpha.
 board+='<defs><pattern id="checks" width="24" height="24" patternUnits="userSpaceOnUse"><rect width="24" height="24" fill="#DDD9E2"/><path d="M0 0H12V12H0Z M12 12H24V24H12Z" fill="#F6F4F8"/></pattern></defs><rect x="1120" y="190" width="260" height="270" fill="url(#checks)"/>';
 board+=`<svg x="1120" y="190" width="260" height="270" viewBox="0 0 100 100">${mark(colours.midnight)}</svg>`+text(1120,503,'Transparent master');
 board+=text(60,594,'SMALL-SIZE CHECK / LIGHT & DARK',18);
 for(const [i,size] of [16,24,32,48,64].entries()){
  const x=60+i*170;board+=tile(x,625,size,colours.lilac,colours.midnight,'square')+text(x,723,`${size}px`,18);
  board+=`<rect x="${x-8}" y="754" width="100" height="100" fill="#120A24"/>`+tile(x,766,size,colours.midnight,colours.bone,'square');
 }
 board+=text(990,610,'LILAC  #B9A0FF',22)+text(990,651,'MIDNIGHT  #120A24',22)+text(990,718,'Gently rounded vector geometry',18)+text(990,751,'Separate transparent foreground',18)+text(990,784,'Full-bleed store exports',18);
 board+=text(60,939,'Corners above simulate platform masks. Apple and store files are square; Android adaptive layers are unmasked.',19);
 board+=text(60,978,'Editable SVG + PNG masters · iPhone / iPad catalogs · Android legacy / adaptive / monochrome · store icons',19);
 const preview=`<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1050" viewBox="0 0 1440 1050">${board}</svg>`;
 write('preview.svg',preview);write('preview.png',await sharp(Buffer.from(preview)).png().toBuffer());
 console.log('Generated After Hours app icon pack.');
})();
