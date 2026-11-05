import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
export default {plugins:[{name:'windows-media-policy',transformIndexHtml:html=>html.replace("connect-src 'self' minivoice-art:","connect-src 'self' minivoice-art:; media-src 'self' mv-audio:")}],root:path.resolve(root,'../MacOS/Desktop'),base:'./',cacheDir:path.resolve(root,'../.build/cache/vite/windows'),resolve:{alias:{react:path.resolve(root,'../Shared/UI/node_modules/react'),'react-dom':path.resolve(root,'../Shared/UI/node_modules/react-dom')}},build:{target:'chrome130',outDir:path.resolve(root,'ui'),emptyOutDir:true}};
