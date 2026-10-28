import base from './vite.config.mjs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
export default {...base,publicDir:path.join(repo,'.build/work/shared-ui'),server:{fs:{allow:[repo]}},plugins:[{name:'wall-fixture-desktop-assets',configureServer(server){server.middlewares.use((request,response,next)=>{const pathname=new URL(request.url,'http://localhost').pathname;if(!/^\/symbols\/[a-zA-Z0-9_-]+\.png$/.test(pathname)&&pathname!=='/app-icon.png')return next();const target=path.join(repo,'MacOS/Desktop/public',pathname.slice(1));if(!fs.existsSync(target))return next();response.setHeader('Content-Type','image/png');fs.createReadStream(target).pipe(response);});}}]};
