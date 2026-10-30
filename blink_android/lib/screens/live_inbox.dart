import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../core/live_api.dart';
import '../core/blink_auth_api.dart';
import '../core/theme.dart';

class LiveInboxScreen extends StatefulWidget {
  const LiveInboxScreen({super.key});
  @override State<LiveInboxScreen> createState() => _LiveInboxState();
}

class _LiveInboxState extends State<LiveInboxScreen> {
  List<dynamic> conversations = [];
  bool loading = true;
  String? error;
  String query = '';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final response = arr(await LiveApi.call('GET', '/inbox'));
      if (mounted) setState(() { conversations = response; loading = false; error = null; });
    } catch (e) { if (mounted) setState(() {error=e.toString();loading=false;}); }
  }
  @override Widget build(BuildContext context) {
    final rows = conversations.where((e) {
      final c = obj(e);
      final person = obj(c['otherUser']);
      final name = c['isGroup']==true ? field(c,'groupName') : field(person,'name');
      return name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox'), actions: [
        IconButton(tooltip:'New chat', icon:const Icon(Icons.edit_square),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LiveNewChatScreen())).then((_){_load();})),
        IconButton(tooltip:'Create group', icon:const Icon(Icons.group_add_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LiveCreateGroupScreen())).then((_){_load();})),
        IconButton(tooltip:'Refresh', icon:const Icon(Icons.refresh),onPressed:_load),
      ]),
      body: Column(children:[
        Padding(padding:const EdgeInsets.all(14),child:TextField(
          decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search conversations'),
          onChanged:(v)=>setState(()=>query=v),
        )),
        Expanded(child:loading?const Center(child:CircularProgressIndicator()):
          error!=null?liveError(error,_load):
          RefreshIndicator(onRefresh:_load,child:ListView.builder(
            itemCount:rows.isEmpty?1:rows.length,
            itemBuilder:(context,i){
              if(rows.isEmpty)return const ListTile(title:Text('No conversations yet'),subtitle:Text('Start chatting with a Blink friend.'));
              final c=obj(rows[i]);final other=obj(c['otherUser']);final group=c['isGroup']==true;
              final name=group?field(c,'groupName','Group'):field(other,'name','Friend');
              final last=obj(c['lastMessage']);final body=field(last,'body');
              final preview=last['unsentAt']!=null?'Message removed':
                body.startsWith('🎬 Reel by')?'🎬 Shared a Reel':
                body.isNotEmpty?body:last['mediaKey']!=null?'Media attachment':'New conversation';
              return ListTile(
                leading:group?const CircleAvatar(child:Icon(Icons.groups)):liveAvatar(other),
                title:Text(name),subtitle:Text(preview,maxLines:1,overflow:TextOverflow.ellipsis),
                trailing: (c['unreadCount'] is num && c['unreadCount']>0)
                  ? CircleAvatar(radius:12,backgroundColor:BlinkColors.orange,child:Text('${c['unreadCount']}',style:const TextStyle(fontSize:11,color:Colors.white))):null,
                onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
                  builder:(_)=>LiveChatScreen(conversationId:field(c,'id'),title:name))).then((_){_load();}),
              );
            },
          )),
        ),
      ]),
    );
  }
}

class LiveNewChatScreen extends StatefulWidget {
  const LiveNewChatScreen({super.key});
  @override State<LiveNewChatScreen> createState()=>_LiveNewChatState();
}
class _LiveNewChatState extends State<LiveNewChatScreen> {
  List<dynamic> friends=[];String? error;String search='';bool busy=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{try{final data=arr(await LiveApi.call('GET','/inbox/friends'));if(mounted)setState((){friends=data;error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}}
  Future<void> _start(dynamic friend)async{
    setState(()=>busy=true);
    try{final result=obj(await LiveApi.call('POST','/inbox/conversations',{'friendId':field(friend,'id')}));
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute<void>(builder:(_)=>LiveChatScreen(
        conversationId:field(result,'conversationId'),title:field(friend,'name'))));
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Message a friend')),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(decoration:const InputDecoration(
        hintText:'Find a friend',prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState(()=>search=v))),
      if(error!=null)liveError(error,_load),
      Expanded(child:ListView(children:friends.where((u)=>field(u,'name').toLowerCase().contains(search.toLowerCase())).map((u)=>ListTile(
        leading:liveAvatar(u),title:Text(field(u,'name')),trailing:const Icon(Icons.chat_bubble_outline),
        enabled:!busy,onTap:()=>_start(u),
      )).toList())),
    ]),
  );
}

class LiveChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  const LiveChatScreen({super.key,required this.conversationId,required this.title});
  @override State<LiveChatScreen> createState()=>_LiveChatState();
}
class _LiveChatState extends State<LiveChatScreen>{
  final input=TextEditingController();
  List<dynamic> messages=[];String? error;String myId='';String bearer='';bool busy=false;bool loading=true;
  Timer? timer;
  @override void initState(){super.initState();_load();timer=Timer.periodic(const Duration(seconds:12),(_)=>_load(silent:true));}
  @override void dispose(){timer?.cancel();input.dispose();super.dispose();}
  Future<void> _load({bool silent=false}) async {
    try{
      final self=await BlinkAuthApi.cachedUser();
      final token=await BlinkAuthApi.getToken() ?? '';
      final data=obj(await LiveApi.call('GET','/inbox/conversations/${Uri.encodeComponent(widget.conversationId)}'));
      if(!mounted)return;
      setState((){myId=field(self,'id');bearer=token;messages=arr(data['messages']);error=null;loading=false;});
      if(!silent)await LiveApi.call('POST','/inbox/conversations/${Uri.encodeComponent(widget.conversationId)}/read');
    }catch(e){if(mounted&&!silent)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _send()async{
    final text=input.text.trim();if(text.isEmpty||busy)return;
    setState(()=>busy=true);
    try{await LiveApi.call('POST','/inbox/conversations/${Uri.encodeComponent(widget.conversationId)}/messages',{'body':text});
      input.clear();await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _upload()async{
    final asset=await ImagePicker().pickMedia();
    if(asset==null)return;setState(()=>busy=true);
    try{await LiveApi.upload('/inbox/conversations/${Uri.encodeComponent(widget.conversationId)}/media',
      File(asset.path));
      await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _action(String method,String path,[Map<String,dynamic>? body])async{
    try{await LiveApi.call(method,path,body);await _load();}catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _openPrivate(Map<String,dynamic> m) async {
    final id = field(m,'id');
    if(id.isEmpty) return;
    try {
      final token = await BlinkAuthApi.getToken();
      if(token==null || token.isEmpty) throw const LiveApiError('Please sign in again.');
      // A private attachment can be opened only once. Never issue a GET first.
      final response=await http.post(
        Uri.parse('${LiveApi.root}/inbox/media/${Uri.encodeComponent(id)}/open'),
        headers: {'Authorization':'Bearer $token'},
      ).timeout(const Duration(seconds:45));
      if(response.statusCode!=200) {
        throw LiveApiError('Private media unavailable (HTTP ${response.statusCode}).');
      }
      if(!mounted) return;
      if(field(m,'mediaType')=='image'){
        await showDialog<void>(context:context,builder:(_)=>Dialog(
          child:InteractiveViewer(child:Image.memory(response.bodyBytes,fit:BoxFit.contain))));
      } else if(field(m,'mediaType')=='video'){
        final temporary=File('${Directory.systemTemp.path}/blink_private_${DateTime.now().microsecondsSinceEpoch}.mp4');
        await temporary.writeAsBytes(response.bodyBytes,flush:true);
        if(!mounted){await temporary.delete();return;}
        await Navigator.push<void>(context,MaterialPageRoute(
          builder:(_)=>_InboxVideoPage(file:temporary)));
      } else {
        liveNotice(context,'This private media format cannot be previewed.');
      }
      await _load();
    } catch(e){if(mounted)liveNotice(context,'$e');}
  }

  Widget _attachment(Map<String,dynamic> m) {
    final id=field(m,'id'),type=field(m,'mediaType');
    final own=field(m,'senderId')==myId;
    if(m['isPrivate']==true){
      if(own)return const Text('🔒 Private Moment sent');
      if(m['privateOpenedAt']!=null)return const Text('🔒 Private Moment already opened');
      return OutlinedButton.icon(
        icon:const Icon(Icons.lock_open,color:BlinkColors.orange),
        label:const Text('View Private Moment once'),
        onPressed:()=>_openPrivate(m));
    }
    final url='${LiveApi.root}/inbox/media/${Uri.encodeComponent(id)}';
    if(type=='image'){
      return ClipRRect(borderRadius:BorderRadius.circular(12),
        child:Image.network(url,headers:{'Authorization':'Bearer $bearer'},
          width:220,height:175,fit:BoxFit.cover,
          errorBuilder:(_,__,___)=>const Text('Image unavailable')));
    }
    if(type=='video'){
      return TextButton.icon(
        icon:const Icon(Icons.play_circle_outline,color:BlinkColors.orange),
        label:const Text('Play video attachment'),
        onPressed:()=>Navigator.push<void>(context,MaterialPageRoute(
          builder:(_)=>_InboxVideoPage(url:url,token:bearer))));
    }
    return Text('📎 ${type.isEmpty?'Attachment':type}');
  }

  String? _reelId(String body){
    if(!body.startsWith('🎬 Reel by '))return null;
    return RegExp(r'/reels/([A-Za-z0-9_-]+)').firstMatch(body)?.group(1);
  }
  Widget _message(Map<String,dynamic> m){
    final own=field(m,'senderId')==myId;
    final reel=_reelId(field(m,'body'));
    final removed=m['unsentAt']!=null;
    return Align(alignment:own?Alignment.centerRight:Alignment.centerLeft,
      child:Container(margin:const EdgeInsets.symmetric(vertical:5,horizontal:12),
        constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width*.82),
        decoration:BoxDecoration(color:own?const Color(0xFFFFE6D5):Colors.grey.shade100,
          borderRadius:BorderRadius.circular(17)),
        padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(removed)const Text('Message removed',style:TextStyle(fontStyle:FontStyle.italic))
          else if(reel!=null)InkWell(
            onTap:()=>Navigator.pushNamed(context,'/reel/view',arguments:reel),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              ClipRRect(borderRadius:BorderRadius.circular(10),
                child:Image.network(LiveApi.url('/reels/media/$reel/thumbnail'),
                  width:220,height:125,fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>const SizedBox(height:65,child:Icon(Icons.movie)))),
              const SizedBox(height:7),
              const Text('🎬 Shared Blink Reel',style:TextStyle(fontWeight:FontWeight.bold)),
              const Text('▶ Watch Reel',style:TextStyle(color:BlinkColors.orange)),
            ]))
          else if(m['mediaKey']!=null)
            _attachment(m)
          else Text(field(m,'body')),
          const SizedBox(height:5),
          Row(mainAxisSize:MainAxisSize.min,children:[
            if(!removed)TextButton(onPressed:()=>_action('POST','/inbox/messages/${field(m,'id')}/reaction',{'emoji':'❤️'}),
              child:const Text('❤️',style:TextStyle(fontSize:11))),
            if(own&&!removed)TextButton(onPressed:()=>_action('POST','/inbox/messages/${field(m,'id')}/unsend'),
              child:const Text('Unsend',style:TextStyle(fontSize:11))),
            TextButton(onPressed:()=>_action('DELETE','/inbox/messages/${field(m,'id')}'),
              child:const Text('Hide',style:TextStyle(fontSize:11))),
          ]),
        ]),
      ),
    );
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.title)),
    body:Column(children:[
      if(error!=null)liveError(error,()=>_load()),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):
        RefreshIndicator(onRefresh:_load,child:ListView.builder(
          itemCount:messages.length,itemBuilder:(_,i)=>_message(obj(messages[i]))))),
      SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(8,8,8,10),
        child:Row(children:[
          IconButton(tooltip:'Attach',onPressed:busy?null:_upload,icon:const Icon(Icons.add_circle_outline,color:BlinkColors.orange)),
          Expanded(child:TextField(controller:input,minLines:1,maxLines:4,decoration:const InputDecoration(hintText:'Message...'))),
          IconButton(tooltip:'Send',onPressed:busy?null:_send,icon:const Icon(Icons.send,color:BlinkColors.orange)),
        ]))),
    ]),
  );
}

/// Friend picker uses the backend's existing Reel sharing implementation.
/// It verifies friendships/blocks and writes messages with Reel thumbnails.
Future<void> shareReelToBlinkFriends(BuildContext context,String reelId)async{
  List<dynamic> friends=[];
  try{friends=arr(await LiveApi.call('GET','/inbox/friends'));}
  catch(e){if(context.mounted)liveNotice(context,e.toString());return;}
  if(!context.mounted)return;
  final selected=<String>{};
  bool sending=false;
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,
    builder:(sheetContext)=>StatefulBuilder(builder:(context,setModal)=>Padding(
      padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),
      child:SizedBox(height:MediaQuery.sizeOf(context).height*.68,
        child:Column(children:[
          const SizedBox(height:12),
          Text('Share Reel with friends',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),
          Text('${selected.length}/10 selected'),
          Expanded(child:friends.isEmpty
            ?const Center(child:Text('Add friends to share Reels in Blink.'))
            :ListView.builder(itemCount:friends.length,itemBuilder:(_,i){
                final friend=friends[i];final id=field(friend,'id');
                return CheckboxListTile(
                  secondary:liveAvatar(friend),title:Text(field(friend,'name')),
                  value:selected.contains(id),activeColor:BlinkColors.orange,
                  onChanged:sending?null:(value)=>setModal((){
                    if(value==true && selected.length>=10){liveNotice(context,'Maximum 10 friends');return;}
                    if(value==true){selected.add(id);}else{selected.remove(id);}
                  }),
                );
              })),
          Padding(padding:const EdgeInsets.all(15),child:SizedBox(width:double.infinity,
            child:FilledButton.icon(
              onPressed:selected.isEmpty||sending?null:()async{
                setModal(()=>sending=true);
                try{final result=obj(await LiveApi.call('POST','/reels/${Uri.encodeComponent(reelId)}/share',
                    {'friendIds':selected.toList()}));
                  if(!context.mounted)return;
                  Navigator.pop(context);
                  if(sheetContext.mounted)liveNotice(sheetContext,'Reel sent to ${field(result,'sent')} friend(s).');
                }catch(e){if(context.mounted)liveNotice(context,e.toString());}
                finally{if(context.mounted)setModal(()=>sending=false);}
              },icon:const Icon(Icons.send),
              label:Text(sending?'Sending...':'Send to ${selected.length} friend(s)')))),
        ])),
    )));
}

class _InboxVideoPage extends StatefulWidget {
  final String? url,token;
  final File? file;
  const _InboxVideoPage({this.url,this.token,this.file});
  @override State<_InboxVideoPage> createState()=>_InboxVideoState();
}
class _InboxVideoState extends State<_InboxVideoPage>{
  late final VideoPlayerController player;
  late final Future<void> ready;
  @override void initState(){
    super.initState();
    player=widget.file!=null
      ?VideoPlayerController.file(widget.file!)
      :VideoPlayerController.networkUrl(Uri.parse(widget.url!),
          httpHeaders:{'Authorization':'Bearer ${widget.token??''}'});
    ready=player.initialize().then((_)=>player.play());
  }
  @override void dispose(){
    player.dispose();
    final temporary=widget.file;
    if(temporary!=null){
      // Best-effort deletion of one-time private video bytes.
      temporary.delete().ignore();
    }
    super.dispose();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:BlinkColors.canvas,
    appBar:AppBar(title:const Text('Blink Video')),
    body:Center(child:FutureBuilder<void>(future:ready,builder:(_,snapshot){
      if(snapshot.hasError)return Text('${snapshot.error}');
      if(snapshot.connectionState!=ConnectionState.done)return const CircularProgressIndicator(color:BlinkColors.orange);
      return AspectRatio(aspectRatio:player.value.aspectRatio,child:GestureDetector(
        onTap:(){if(player.value.isPlaying){player.pause();}else{player.play();}setState((){});},
        child:VideoPlayer(player)));
    })),
  );
}

class LiveCreateGroupScreen extends StatefulWidget {
  const LiveCreateGroupScreen({super.key});
  @override State<LiveCreateGroupScreen> createState()=>_CreateGroupState();
}
class _CreateGroupState extends State<LiveCreateGroupScreen>{
  final name=TextEditingController();
  List<dynamic> friends=[];
  final selected=<String>{};
  String? error;
  bool loading=true,busy=false;
  @override void initState(){super.initState();_load();}
  @override void dispose(){name.dispose();super.dispose();}
  Future<void> _load()async{
    try{
      final response=arr(await LiveApi.call('GET','/inbox/friends'));
      if(mounted)setState((){friends=response;loading=false;error=null;});
    }catch(e){if(mounted)setState((){loading=false;error='$e';});}
  }
  Future<void> _create()async{
    if(busy)return;
    setState(()=>busy=true);
    try{
      final result=obj(await LiveApi.call('POST','/inbox/groups',
        {'name':name.text.trim(),'friendIds':selected.toList()}));
      final id=field(result,'conversationId');
      if(id.isEmpty)throw const LiveApiError('Group was not created.');
      if(!mounted)return;
      Navigator.pushReplacement<void,void>(context,MaterialPageRoute(
        builder:(_)=>LiveChatScreen(conversationId:id,title:name.text.trim())));
    }catch(e){if(mounted)liveNotice(context,'$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Create Blink Group')),
    body:loading?const Center(child:CircularProgressIndicator()):
      error!=null?liveError(error,_load):
      Column(children:[
        Padding(padding:const EdgeInsets.all(14),child:TextField(controller:name,maxLength:60,
          decoration:const InputDecoration(hintText:'Group name',prefixIcon:Icon(Icons.groups)))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Text(
          '${selected.length} members selected',style:Theme.of(context).textTheme.titleSmall)),
        Expanded(child:ListView.builder(itemCount:friends.length,itemBuilder:(_,i){
          final friend=friends[i],id=field(friend,'id');
          return CheckboxListTile(
            secondary:liveAvatar(friend),title:Text(field(friend,'name')),
            activeColor:BlinkColors.orange,value:selected.contains(id),
            onChanged:(v)=>setState((){
              if(v==true){selected.add(id);}else{selected.remove(id);}
            }));
        })),
        SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(15),
          child:SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:busy||name.text.trim().isEmpty||selected.isEmpty?null:_create,
            icon:const Icon(Icons.group_add),label:Text(busy?'Creating...':'Create group'))))),
      ]),
  );
}
