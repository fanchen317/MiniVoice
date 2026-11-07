const {app,nativeImage}=require('electron'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
app.whenReady().then(async()=>{const directory=await fs.mkdtemp(path.join(os.tmpdir(),'minivoice-preview-real-'));try{
 const pixels=Buffer.alloc(4000*3000*4);for(let y=0;y<3000;y++)for(let x=0;x<4000;x++){const i=(y*4000+x)*4;pixels[i]=x%256;pixels[i+1]=y%256;pixels[i+2]=(x+y)%256;pixels[i+3]=255;}
 const original=nativeImage.createFromBitmap(pixels,{width:4000,height:3000}).toPNG(),key='a'.repeat(64);await fs.writeFile(path.join(directory,key),original);
 const {artworkPreviews}=require('../../Windows/electron/artwork-previews.cjs'),service=artworkPreviews({directory,nativeImage});const values=await Promise.all(Array.from({length:20},()=>service.get(key)));assert.equal(service.stats.generated,1);
 const browse=nativeImage.createFromBuffer(values[0].data).getSize(),list=nativeImage.createFromBuffer((await service.get(key,{list:true})).data).getSize();assert.deepEqual(browse,{width:512,height:384});assert.deepEqual(list,{width:192,height:144});assert.deepEqual((await service.get(key,{original:true})).data,original);
 const again=artworkPreviews({directory,nativeImage});await again.get(key);assert.equal(again.stats.diskHits,1);
 const report={host:process.platform,source:{width:4000,height:3000,bytes:original.length},browse,list,concurrentRequests:20,decodeCount:1,originalBytesPreserved:true,decodedPixelReduction:4000*3000/(512*384),windowsFPSMeasured:false};
 await fs.writeFile(path.resolve('.build/reports/build/windows-preview-pipeline.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));app.exit(0);
 }catch(error){console.error(error);app.exit(1);}finally{await fs.rm(directory,{recursive:true,force:true});}});
