import {useSurfaceMotion as useSharedSurfaceMotion} from '../../../Shared/UI/src/components/useSurfaceMotion.js';
import {springEasing} from './motion';
const easing=springEasing(.32,.92,260);
export function useSurfaceMotion(ref,open,options={}){useSharedSurfaceMotion(ref,open,{...options,easing});}
