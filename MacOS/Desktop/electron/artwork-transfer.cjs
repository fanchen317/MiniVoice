const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function artworkTransfer({nativeImage,clipboard,resolveFile,directory}){
 function image(src){
  if(typeof src!=='string'||src.length>28*1024*1024)throw Error('图片过大');
  let value;
  if(/^data:image\/(png|jpeg|webp);base64,[a-zA-Z0-9+/=]+$/.test(src)){if(Buffer.from(src.slice(src.indexOf(',')+1),'base64').length>20*1024*1024)throw Error('图片过大');value=nativeImage.createFromDataURL(src);}
  else {const file=resolveFile(src);if(!file)throw Error('图片尚未读取完成');value=nativeImage.createFromPath(file);}
  if(value.isEmpty())throw Error('无法读取图片');const size=value.getSize();if(size.width*size.height>40000000)throw Error('图片尺寸过大');return value;
 }
 return {copy:src=>{clipboard.writeImage(image(src));return true;},paste:()=>{const value=clipboard.readImage();if(value.isEmpty())throw Error('剪贴板中没有图片');const src=value.toDataURL();image(src);return src;},drag:(sender,src)=>{const value=image(src);fs.mkdirSync(directory,{recursive:true});const file=path.join(directory,`MiniVoice-artwork-${crypto.randomUUID()}.png`);fs.writeFileSync(file,value.toPNG());sender.startDrag({file,icon:value.resize({width:96})});return file;},cleanup:()=>fs.rmSync(directory,{recursive:true,force:true})};
}
module.exports={artworkTransfer};
