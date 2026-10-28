import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.dirname(fileURLToPath(import.meta.url));
export default {root,base:'./',cacheDir:path.resolve(root,'../../.build/cache/vite/shared-ui'),resolve:{alias:{react:path.resolve(root,'node_modules/react'),'react-dom':path.resolve(root,'node_modules/react-dom')}},build:{target:'chrome100',cssMinify:false,outDir:path.resolve(root,'../../.build/work/shared-ui'),emptyOutDir:true}};
