package com.xcosmos.minivoice;

import android.database.*;
import android.os.*;
import android.provider.*;
import java.io.*;

/** Synthetic WAV directory used only by the separately installed emulator test APK. */
public final class TestMusicProvider extends android.content.ContentProvider {
    static final String AUTHORITY="com.xcosmos.minivoice.uitests.music";
    private static final String[] DOCUMENTS={DocumentsContract.Document.COLUMN_DOCUMENT_ID,DocumentsContract.Document.COLUMN_DISPLAY_NAME,DocumentsContract.Document.COLUMN_MIME_TYPE,DocumentsContract.Document.COLUMN_FLAGS,DocumentsContract.Document.COLUMN_SIZE,DocumentsContract.Document.COLUMN_LAST_MODIFIED};
    private volatile boolean edited,removed;
    private volatile int reads;
    @Override public boolean onCreate(){return true;}
    @Override public String getType(android.net.Uri uri){return "audio/wav";}
    @Override public Cursor query(android.net.Uri uri,String[] projection,String selection,String[] args,String sort){
        MatrixCursor cursor=new MatrixCursor(projection==null?DOCUMENTS:projection);
        if(uri.getPathSegments().contains("children")){if(android.provider.DocumentsContract.getDocumentId(uri).equals("root")){add(cursor,"one.wav");if(!removed)add(cursor,"two.wav");}}
        else add(cursor,android.provider.DocumentsContract.getDocumentId(uri));return cursor;
    }
    @Override public android.net.Uri insert(android.net.Uri uri,android.content.ContentValues values){throw new UnsupportedOperationException();}
    @Override public int update(android.net.Uri uri,android.content.ContentValues values,String selection,String[] args){throw new UnsupportedOperationException();}
    @Override public int delete(android.net.Uri uri,String selection,String[] args){throw new UnsupportedOperationException();}
    private void add(MatrixCursor cursor,String id){boolean root=id.equals("root");MatrixCursor.RowBuilder row=cursor.newRow();for(String column:cursor.getColumnNames()){
        Object value=null;
        if(column.equals(DocumentsContract.Document.COLUMN_DOCUMENT_ID)||column.equals(DocumentsContract.Document.COLUMN_DISPLAY_NAME))value=id;
        else if(column.equals(DocumentsContract.Document.COLUMN_MIME_TYPE))value=root?DocumentsContract.Document.MIME_TYPE_DIR:"audio/wav";
        else if(column.equals(DocumentsContract.Document.COLUMN_FLAGS))value=0;
        else if(column.equals(DocumentsContract.Document.COLUMN_SIZE))value=root?0:16044L;
        else if(column.equals(DocumentsContract.Document.COLUMN_LAST_MODIFIED))value=edited&&id.equals("one.wav")?2000L:1000L;
        row.add(value);
    }}
    @Override public ParcelFileDescriptor openFile(android.net.Uri uri,String mode)throws FileNotFoundException{
        String id=android.provider.DocumentsContract.getDocumentId(uri);
        if(!mode.equals("r")||id.equals("root")||removed&&id.equals("two.wav"))throw new FileNotFoundException();reads++;
        File file=new File(getContext().getCacheDir(),id);
        if(!file.exists())try(FileOutputStream out=new FileOutputStream(file)){
            java.nio.ByteBuffer header=java.nio.ByteBuffer.allocate(44).order(java.nio.ByteOrder.LITTLE_ENDIAN);header.put("RIFF".getBytes()).putInt(16036).put("WAVEfmt ".getBytes()).putInt(16).putShort((short)1).putShort((short)1).putInt(8000).putInt(16000).putShort((short)2).putShort((short)16).put("data".getBytes()).putInt(16000);out.write(header.array());out.write(new byte[16000]);
        }catch(IOException failure){throw new FileNotFoundException(failure.toString());}
        return ParcelFileDescriptor.open(file,ParcelFileDescriptor.MODE_READ_ONLY);
    }
    @Override public Bundle call(String method,String argument,Bundle extras){Bundle result=new Bundle();if(method.equals("reset")){edited=false;removed=false;reads=0;}else if(method.equals("edit"))edited=true;else if(method.equals("remove"))removed=true;else if(!method.equals("stats"))return super.call(method,argument,extras);result.putInt("reads",reads);return result;}
}
