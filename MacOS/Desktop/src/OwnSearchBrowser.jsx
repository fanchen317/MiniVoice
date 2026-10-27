import React from 'react';
import {Modal} from './Modal';
import SearchWorkspace from '../../../Shared/UI/src/components/SearchWorkspace.jsx';
/** Host shell only; reusable search presentation receives data and callbacks. */
export default function OwnSearchBrowser(props){return <Modal title={props.title} className="own-panel own-search-modal" onClose={props.onBack}><SearchWorkspace {...props}/></Modal>;}
