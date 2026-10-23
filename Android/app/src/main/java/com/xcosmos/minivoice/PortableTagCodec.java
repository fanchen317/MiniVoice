package com.xcosmos.minivoice;
import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.util.*;
/** Platform-independent, lossless audio payload copy; strict metadata bounds. */
final class PortableTagCodec {
 static final int LIMIT=16*1024*1024;
 static void rewrite(File source,File target,String format,String title,String artist,String album,String lyrics)throws IOException{
  if(format.equals("m4a")){PortableM4aTags.rewrite(source,target,title,artist,album,lyrics);return;}
  try(DataInputStream in=new DataInputStream(new BufferedInputStream(new FileInputStream(source)));OutputStream out=new BufferedOutputStream(new FileOutputStream(target))){if(format.equals("mp3"))mp3(in,out,title,artist,album,lyrics);else if(format.equals("flac"))flac(in,out,title,artist,album,lyrics);else throw new IOException("此格式暂不支持写入标签，请使用应用内歌词保存");}
 }
 static int sync(byte[] bytes,int pos)throws IOException{int n=0;for(int i=0;i<4;i++){int value=bytes[pos+i]&255;if(value>127)throw new IOException("无效的 ID3 长度");n=(n<<7)|value;}return n;}
 static byte[] size(int value,boolean sync){return new byte[]{(byte)(value>>(sync?21:24)),(byte)((value>>(sync?14:16))&(sync?127:255)),(byte)((value>>(sync?7:8))&(sync?127:255)),(byte)(value&(sync?127:255))};}
 static byte[] read(DataInputStream in,int count)throws IOException{if(count<0||count>LIMIT)throw new IOException("标签过大或已损坏");byte[] data=new byte[count];in.readFully(data);return data;}
 static void frame(OutputStream out,String id,byte[] body,int version)throws IOException{out.write(id.getBytes(StandardCharsets.US_ASCII));out.write(size(body.length,version==4));out.write(new byte[2]);out.write(body);}
 static byte[] text(String value,int version){byte[] body=value.getBytes(version==4?StandardCharsets.UTF_8:StandardCharsets.UTF_16);byte[] result=new byte[body.length+1];result[0]=(byte)(version==4?3:1);System.arraycopy(body,0,result,1,body.length);return result;}
 static void mp3(DataInputStream in,OutputStream out,String title,String artist,String album,String lyrics)throws IOException{
  byte[] header=read(in,10);int version=4;ByteArrayOutputStream frames=new ByteArrayOutputStream();
  if(header[0]=='I'&&header[1]=='D'&&header[2]=='3'){
   version=header[3];if((version!=3&&version!=4)||header[4]!=0||header[5]!=0)throw new IOException("此 ID3 标签含旧版或特殊扩展，暂不支持无损编辑");
   byte[] tag=read(in,sync(header,6));int offset=0;
   while(offset<tag.length){if(tag[offset]==0){for(int i=offset;i<tag.length;i++)if(tag[i]!=0)throw new IOException("无效的 ID3 填充");break;}if(offset+10>tag.length)throw new IOException("ID3 帧不完整");String id=new String(tag,offset,4,StandardCharsets.US_ASCII);if(!id.matches("[A-Z0-9]{4}"))throw new IOException("无效的 ID3 帧");int length=version==4?sync(tag,offset+4):ByteBuffer.wrap(tag,offset+4,4).getInt();if(length<=0||length>tag.length-offset-10)throw new IOException("ID3 帧长度错误");if(!Arrays.asList("TIT2","TPE1","TALB","USLT","SYLT").contains(id))frames.write(tag,offset,10+length);offset+=10+length;
   }
  }else{
   if((header[0]&255)!=255||(header[1]&224)!=224)throw new IOException("文件并非可识别的 MP3");
  }
  frame(frames,"TIT2",text(title,version),version);frame(frames,"TPE1",text(artist,version),version);frame(frames,"TALB",text(album,version),version);
  ByteArrayOutputStream lyric=new ByteArrayOutputStream();lyric.write(version==4?3:1);lyric.write("und".getBytes(StandardCharsets.US_ASCII));if(version==4)lyric.write(0);else lyric.write(new byte[]{(byte)255,(byte)254,0,0});lyric.write(lyrics.getBytes(version==4?StandardCharsets.UTF_8:StandardCharsets.UTF_16));frame(frames,"USLT",lyric.toByteArray(),version);
  if(frames.size()>LIMIT)throw new IOException("新标签过大");out.write(new byte[]{'I','D','3',(byte)version,0,0});out.write(size(frames.size(),true));frames.writeTo(out);
  if(!(header[0]=='I'&&header[1]=='D'&&header[2]=='3'))out.write(header);in.transferTo(out);
 }
 static int little(DataInputStream in)throws IOException{int value=Integer.reverseBytes(in.readInt());if(value<0||value>LIMIT)throw new IOException("FLAC 注释长度无效");return value;}
 static void little(OutputStream out,int value)throws IOException{out.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(value).array());}
 static void flac(DataInputStream in,OutputStream out,String title,String artist,String album,String lyrics)throws IOException{
  if(in.readInt()!=0x664c6143)throw new IOException("文件并非 FLAC");List<Integer> types=new ArrayList<>();List<byte[]> blocks=new ArrayList<>();List<byte[]> comments=new ArrayList<>();byte[] vendor="MiniVoice".getBytes(StandardCharsets.UTF_8);boolean last=false,seenComment=false;int total=0;
  while(!last){int flag=in.readUnsignedByte();last=(flag&128)!=0;int type=flag&127,length=(in.readUnsignedByte()<<16)|(in.readUnsignedByte()<<8)|in.readUnsignedByte();total+=length;if(total>LIMIT||types.size()>10000||type==127)throw new IOException("FLAC 标签过大或损坏");byte[] data=read(in,length);if(types.isEmpty()&&(type!=0||length!=34))throw new IOException("FLAC 缺少 STREAMINFO");
   if(type==4){if(seenComment)throw new IOException("FLAC 含重复注释块");seenComment=true;DataInputStream info=new DataInputStream(new ByteArrayInputStream(data));vendor=read(info,little(info));int count=little(info);if(count>data.length/4)throw new IOException("FLAC 注释数量错误");for(int i=0;i<count;i++){byte[] entry=read(info,little(info));String value=new String(entry,StandardCharsets.UTF_8),key=value.contains("=")?value.substring(0,value.indexOf('=')).toUpperCase(Locale.ROOT):"";if(!Arrays.asList("TITLE","ARTIST","ALBUM","LYRICS","UNSYNCEDLYRICS").contains(key))comments.add(entry);}if(info.available()!=0)throw new IOException("FLAC 注释块含多余数据");
   }else if(type!=1){types.add(type);blocks.add(data);}
  }
  for(String value:new String[]{"TITLE="+title,"ARTIST="+artist,"ALBUM="+album,"LYRICS="+lyrics})comments.add(value.getBytes(StandardCharsets.UTF_8));
  ByteArrayOutputStream comment=new ByteArrayOutputStream();little(comment,vendor.length);comment.write(vendor);little(comment,comments.size());for(byte[] entry:comments){little(comment,entry.length);comment.write(entry);}types.add(4);blocks.add(comment.toByteArray());out.write(new byte[]{'f','L','a','C'});
  for(int i=0;i<blocks.size();i++){byte[] data=blocks.get(i);if(data.length>0xffffff)throw new IOException("FLAC 标签过大");out.write(types.get(i)|(i+1==blocks.size()?128:0));out.write(new byte[]{(byte)(data.length>>16),(byte)(data.length>>8),(byte)data.length});out.write(data);}in.transferTo(out);
 }
}
