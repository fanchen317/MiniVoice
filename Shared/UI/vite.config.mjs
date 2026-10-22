import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.dirname(fileURLToPath(import.meta.url));
export default {root,base:'./',resolve:{alias:{react:path.resolve(root,'../../MacOS/Desktop/node_modules/react'),'react-dom':path.resolve(root,'../../MacOS/Desktop/node_modules/react-dom')}},build:{target:'chrome100',outDir:path.resolve(root,'../../.build/Shared/UI'),emptyOutDir:true}};
