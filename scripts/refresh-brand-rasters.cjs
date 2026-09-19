// Requires Node and sharp. Run from any directory; preserves vector native assets.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const mark = fs.readFileSync(path.join(root, 'assets/brand/after-hours-f.svg'));
const icon = fs.readFileSync(path.join(root, 'assets/brand/app-icon.svg'));
async function png(file, source, size, opaque = false) {
  let image = sharp(source).resize(size, size);
  if (opaque) image = image.removeAlpha();
  await image.png().toFile(path.join(root, file));
}
(async () => {
  await png('assets/icon/flixie_icon_1024.png', icon, 1024, true);
  await png('assets/icon/flixie_f_transparent.png', mark, 768);
  const apple = 'ios/Runner/Assets.xcassets';
  for (const scale of [1, 2, 3]) {
    await png(`${apple}/LaunchImage.imageset/LaunchImage${scale === 1 ? '' : `@${scale}x`}.png`, mark, 192 * scale);
  }
  // Also refresh old, unreferenced catalog rasters so no previous logo remains.
  for (const file of fs.readdirSync(path.join(root, apple, 'AppIcon.appiconset'))) {
    if (!file.startsWith('Icon-App-') || !file.endsWith('.png')) continue;
    const target = `${apple}/AppIcon.appiconset/${file}`;
    const {width} = await sharp(path.join(root, target)).metadata();
    await png(target, icon, width, true);
  }
  const bg = await sharp({create:{width:1,height:1,channels:3,background:'#120A24'}}).png().toBuffer();
  fs.writeFileSync(path.join(root, apple, 'LaunchBackground.imageset/background.png'), bg);
  const res = 'android/app/src/main/res';
  for (const folder of ['drawable','drawable-v21']) fs.writeFileSync(path.join(root,res,folder,'background.png'), bg);
  for (const [density, scale] of [['mdpi',1],['hdpi',1.5],['xhdpi',2],['xxhdpi',3],['xxxhdpi',4]]) {
    await png(`${res}/drawable-${density}/splash.png`,mark,192*scale);
    // Android 12: 288 dp canvas, visible F entirely inside central 192 dp circle.
    const visible = await sharp(mark).resize(192*scale).png().toBuffer();
    const splash = await sharp({create:{width:288*scale,height:288*scale,channels:4,background:'#00000000'}}).composite([{input:visible,gravity:'centre'}]).png().toBuffer();
    for (const qualifier of ['', 'night-']) fs.writeFileSync(path.join(root,res,`drawable-${qualifier}${density}`,'android12splash.png'),splash);
    // Retained legacy foreground file names are refreshed as well.
    await png(`${res}/drawable-${density}/ic_launcher_foreground.png`, mark, 108*scale);
  }
  console.log('Updated Flutter symbols and native launch artwork.');
})();
