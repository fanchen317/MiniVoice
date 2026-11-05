const path=require('node:path'),fs=require('node:fs');
function tools(){const {app}=require('electron'),root=app.isPackaged?path.join(process.resourcesPath,'app.asar.unpacked','resources'):path.join(__dirname,'..','resources');return {ffmpeg:path.join(root,'ffmpeg.exe'),ffprobe:path.join(root,'ffprobe.exe')};}
function available(){const value=tools();return fs.existsSync(value.ffmpeg)&&fs.existsSync(value.ffprobe);}
async function write(file,patch,options){if(available()){let service;try{service=require('./shared-services/media-tag-writer.cjs');}catch(error){if(error.code!=='MODULE_NOT_FOUND')throw error;service=require('../../Shared/DesktopServices/media-tag-writer.cjs');}return service.writeMediaTags(file,patch,{...tools(),...options});}return require('./tag-writer.cjs').writeMP3(file,patch,options);}
module.exports={write,available};
