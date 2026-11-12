// Build the real shared inference entry as an isolated Electron test fixture.
import {build} from '../../../Shared/UI/node_modules/vite/dist/node/index.js';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=fileURLToPath(new URL('../../../Shared/UI/',import.meta.url));
if(!process.argv[2])throw Error('Expected output directory');
await build({configFile:false,root,base:'./',logLevel:'warn',build:{target:'chrome100',outDir:path.resolve(process.argv[2]),emptyOutDir:true,rollupOptions:{preserveEntrySignatures:'strict',input:path.join(root,'src/artworkSubjectDetector.js')}}});
