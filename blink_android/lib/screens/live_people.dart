import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/live_api.dart';
import '../core/theme.dart';

class LiveDiscoverPeopleScreen extends StatefulWidget{
  const LiveDiscoverPeopleScreen({super.key});
  @override State<LiveDiscoverPeopleScreen> createState()=>_DiscoverState();
}
class _DiscoverState extends State<LiveDiscoverPeopleScreen>{
  List<dynamic> users=[];String query='';String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/friends/search?q=${Uri.encodeQueryComponent(query)}'));
      if(mounted)setState((){users=rows;loading=false;error=null;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _request(String id)async{
    try{await LiveApi.call('POST','/friends/requests',{'receiverId':id});if(mounted)liveNotice(context,'Friend request sent');}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Discover People'),actions:[
    IconButton(icon:const Icon(Icons.people),tooltip:'My friends',onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LiveFriendsScreen()))),
    IconButton(icon:const Icon(Icons.person_add_alt),tooltip:'Requests',onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LiveRequestsScreen()))),
  ]),body:Column(children:[
    Padding(padding:const EdgeInsets.all(14),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search Blink members'),onChanged:(v)=>query=v,onSubmitted:(_)=>_load())),
    Expanded(child:loading?const Center(child:CircularProgressIndicator()):
      error!=null?liveError(error,_load):
      RefreshIndicator(onRefresh:_load,child:ListView.builder(itemCount:users.length,itemBuilder:(_,i){
        final user=users[i];return ListTile(leading:liveAvatar(user),title:Text(field(user,'name')),
          subtitle:Text(field(user,'bio','Blink member'),maxLines:1,overflow:TextOverflow.ellipsis),
          onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LivePublicProfileScreen(userId:field(user,'id')))),
          trailing:IconButton(icon:const Icon(Icons.person_add_alt,color:BlinkColors.orange),onPressed:()=>_request(field(user,'id'))));
      }))),
  ]));
}

class LiveFriendsScreen extends StatefulWidget{
  const LiveFriendsScreen({super.key});
  @override State<LiveFriendsScreen> createState()=>_FriendsState();
}
class _FriendsState extends State<LiveFriendsScreen>{
  List<dynamic> friends=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/friends'));if(mounted)setState((){friends=rows;loading=false;error=null;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('My Friends')),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(children:[
      if(friends.isEmpty)const ListTile(title:Text('No friends yet'),subtitle:Text('Discover people and send a friend request.')),
      ...friends.map((row){final user=obj(obj(row)['user']);return ListTile(
        leading:liveAvatar(user),title:Text(field(user,'name')),
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LivePublicProfileScreen(userId:field(user,'id')))),
        trailing:IconButton(tooltip:'Unfriend',icon:const Icon(Icons.person_remove_outlined),onPressed:()async{
          try{await LiveApi.call('DELETE','/friends/${Uri.encodeComponent(field(user,'id'))}');await _load();}
          catch(e){if(context.mounted)liveNotice(context,e.toString());}
        }),
      );}),
    ])));
}

class LiveRequestsScreen extends StatefulWidget{
  const LiveRequestsScreen({super.key});
  @override State<LiveRequestsScreen> createState()=>_RequestsState();
}
class _RequestsState extends State<LiveRequestsScreen>{
  List<dynamic> incoming=[],outgoing=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=await Future.wait([
      LiveApi.call('GET','/friends/requests/incoming'),
      LiveApi.call('GET','/friends/requests/outgoing'),
    ]);if(mounted)setState((){incoming=arr(rows[0]);outgoing=arr(rows[1]);error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _respond(dynamic request,String answer)async{
    try{await LiveApi.call('POST','/friends/requests/${Uri.encodeComponent(field(request,'id'))}/$answer');await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Friend Requests')),body:
    loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(children:[
      const ListTile(title:Text('Incoming requests',style:TextStyle(fontWeight:FontWeight.bold))),
      if(incoming.isEmpty)const ListTile(title:Text('No incoming requests')),
      ...incoming.map((r)=>ListTile(leading:liveAvatar(obj(r)['sender']),
        title:Text(field(obj(r)['sender'],'name')),trailing:Wrap(spacing:4,children:[
          TextButton(onPressed:()=>_respond(r,'accept'),child:const Text('Accept')),
          TextButton(onPressed:()=>_respond(r,'decline'),child:const Text('Decline')),
        ]))),
      const Divider(),const ListTile(title:Text('Sent requests',style:TextStyle(fontWeight:FontWeight.bold))),
      ...outgoing.map((r)=>ListTile(leading:liveAvatar(obj(r)['receiver']),
        title:Text(field(obj(r)['receiver'],'name')),trailing:const Text('Pending'))),
    ])));
}

class LiveProfileScreen extends StatefulWidget{
  const LiveProfileScreen({super.key});
  @override State<LiveProfileScreen> createState()=>_ProfileState();
}
class _ProfileState extends State<LiveProfileScreen>{
  Map<String,dynamic>? profile;String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final value=obj(await LiveApi.call('GET','/profile/me'));if(mounted)setState((){profile=value;error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  @override Widget build(BuildContext context){
    final p=profile??{};
    return Scaffold(appBar:AppBar(title:const Text('My Profile'),actions:[
      IconButton(tooltip:'Edit profile',icon:const Icon(Icons.edit),onPressed:()=>Navigator.push(context,
        MaterialPageRoute<void>(builder:(_)=>const LiveEditProfileScreen())).then((_){_load();})),
      IconButton(tooltip:'Settings',icon:const Icon(Icons.settings),onPressed:()=>Navigator.pushNamed(context,'/settings')),
    ]),body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
      RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
        if(field(p,'coverKey').isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(12),
          child:Image.network(LiveApi.url(field(p,'coverKey')),height:135,fit:BoxFit.cover)),
        const SizedBox(height:15),Center(child:liveAvatar(p,radius:49)),
        const SizedBox(height:12),Center(child:Text(field(p,'name'),style:Theme.of(context).textTheme.headlineSmall)),
        Center(child:Text(field(p,'bio','Welcome to Blink'))),
        const SizedBox(height:12),
        Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
          _stat(field(p,'followersCount','0'),'Followers'),
          _stat(field(p,'followingCount','0'),'Following'),
          _stat(field(p,'connectionsCount','0'),'Friends'),
        ]),
        const SizedBox(height:20),
        _info('Email',field(p,'email')),
        _info('Occupation',field(p,'occupation')),
        _info('Workplace',field(p,'workplace')),
        _info('College',field(p,'college')),
        _info('High School',field(p,'highSchool')),
        FilledButton.icon(onPressed:()=>Navigator.pushNamed(context,'/home'),icon:const Icon(Icons.photo_library),
          label:const Text('View My Moments (Home → My Moments)')),
        OutlinedButton.icon(onPressed:()=>Navigator.pushNamed(context,'/people/friends'),
          icon:const Icon(Icons.people),label:const Text('My Friends')),
      ])),
    );
  }
  Widget _stat(String n,String label)=>Column(children:[Text(n,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),Text(label)]);
  Widget _info(String label,String value)=>value.isEmpty?const SizedBox.shrink():ListTile(
    dense:true,title:Text(label),subtitle:Text(value));
}

class LiveEditProfileScreen extends StatefulWidget{
  const LiveEditProfileScreen({super.key});
  @override State<LiveEditProfileScreen> createState()=>_EditState();
}
class _EditState extends State<LiveEditProfileScreen>{
  final controllers=<String,TextEditingController>{for(final key in ['name','bio','college','highSchool','occupation','workplace']) key:TextEditingController()};
  bool busy=false;String? error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){for(final c in controllers.values){c.dispose();}super.dispose();}
  Future<void> _load()async{
    try{final p=obj(await LiveApi.call('GET','/profile/me'));
      for(final item in controllers.entries){item.value.text=field(p,item.key);}
      if(mounted)setState(()=>error=null);
    }catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> _save()async{
    setState(()=>busy=true);
    try{await LiveApi.call('PATCH','/profile/me',controllers.map((k,v)=>MapEntry(k,v.text.trim())));
      if(mounted){liveNotice(context,'Profile updated');Navigator.pop(context);}
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _upload(String kind)async{
    final photo=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:85);
    if(photo==null)return;
    setState(()=>busy=true);
    try{await LiveApi.upload('/profile/me/$kind',File(photo.path));if(mounted)liveNotice(context,'Photo updated');}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Edit Profile')),body:ListView(
    padding:const EdgeInsets.all(18),children:[
      if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
      Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:busy?null:()=>_upload('avatar'),icon:const Icon(Icons.person),
          label:const Text('Avatar'))),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(onPressed:busy?null:()=>_upload('cover'),icon:const Icon(Icons.image),
          label:const Text('Cover'))),
      ]),
      ...controllers.entries.map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:TextField(
        controller:e.value,maxLines:e.key=='bio'?3:1,
        decoration:InputDecoration(labelText:e.key, border:const OutlineInputBorder()))),
      const SizedBox(height:15),
      FilledButton(onPressed:busy?null:_save,child:Text(busy?'Saving...':'Save profile')),
    ]));
}

class LivePublicProfileScreen extends StatefulWidget{
  final String userId;
  const LivePublicProfileScreen({super.key,required this.userId});
  @override State<LivePublicProfileScreen> createState()=>_PublicState();
}
class _PublicState extends State<LivePublicProfileScreen>{
  Map<String,dynamic>? profile;String? error;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final p=obj(await LiveApi.call('GET','/profile/${Uri.encodeComponent(widget.userId)}'));
      if(mounted)setState((){profile=p;error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  @override Widget build(BuildContext context){
    final p=profile??{};
    return Scaffold(appBar:AppBar(title:const Text('Blink Profile')),
      body:profile==null?liveError(error,_load):ListView(padding:const EdgeInsets.all(16),children:[
        Center(child:liveAvatar(p,radius:50)),const SizedBox(height:12),
        Center(child:Text(field(p,'name'),style:Theme.of(context).textTheme.titleLarge)),
        Center(child:Text(field(p,'bio'))),
        ListTile(title:const Text('Connections'),trailing:Text(field(p,'connectionsCount','0'))),
        if(p['isFriend']!=true)FilledButton.icon(onPressed:()async{
          try{await LiveApi.call('POST','/friends/requests',{'receiverId':widget.userId});
            if(context.mounted)liveNotice(context,'Friend request sent');}
          catch(e){if(context.mounted)liveNotice(context,e.toString());}
        },icon:const Icon(Icons.person_add),label:const Text('Add Friend')),
      ]));
  }
}
