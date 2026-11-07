import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/blink_auth_api.dart';
import '../core/live_api.dart';
import '../core/theme.dart';
import 'live_activities.dart' show LiveIrlChatScreen;

const _irlCategories=['All','Hangout','Sports','Gaming','Food','Shopping','Other'];

class FullIrlScreen extends StatefulWidget{
  const FullIrlScreen({super.key});
  @override State<FullIrlScreen> createState()=>_IrlState();
}
class _IrlState extends State<FullIrlScreen>{
  List<dynamic> plans=[];String error='',myId='',filter='All';
  bool mine=false,loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final user=await BlinkAuthApi.cachedUser();
      final rows=arr(await LiveApi.call('GET','/irl/plans'));
      if(mounted)setState((){plans=rows;myId=field(user,'id');error='';loading=false;});
    }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _create()async{
    final title=TextEditingController(),description=TextEditingController(),place=TextEditingController();
    String category='Hangout';
    var start=DateTime.now().add(const Duration(days:1));
    final form=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>
      StatefulBuilder(builder:(ctx,update)=>AlertDialog(
        title:const Text('Create an IRL plan'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:title,maxLength:120,decoration:const InputDecoration(labelText:'Plan title')),
          TextField(controller:description,maxLines:3,maxLength:1000,
            decoration:const InputDecoration(labelText:'Description')),
          TextField(controller:place,maxLength:180,decoration:const InputDecoration(labelText:'Place')),
          DropdownButtonFormField<String>(initialValue:category,
            items:_irlCategories.skip(1).map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
            onChanged:(v){if(v!=null)update(()=>category=v);}),
          TextButton.icon(icon:const Icon(Icons.calendar_month),
            label:Text('Starts: '+start.toLocal().toString().substring(0,16)),
            onPressed:()async{
              final date=await showDatePicker(context:ctx,initialDate:start,
                firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:730)));
              if(date==null||!ctx.mounted)return;
              final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(start));
              if(t!=null)update(()=>start=DateTime(date.year,date.month,date.day,t.hour,t.minute));
            }),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,{
            'title':title.text.trim(),'description':description.text.trim(),
            'place':place.text.trim(),'category':category,'startsAt':start.toUtc().toIso8601String(),
          }),child:const Text('Create'))],
      )));
    title.dispose();description.dispose();place.dispose();
    if(form==null)return;
    try{await LiveApi.call('POST','/irl/plans',form);_load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _interest(String id,bool withdrawn)async{
    final controller=TextEditingController();
    String? reply;
    if(!withdrawn){
      reply=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Reply to IRL invitation'),content:TextField(
          controller:controller,maxLength:500,maxLines:3,
          decoration:const InputDecoration(labelText:'Interest message (optional)')),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),
            child:const Text('Interested'))]));
    }
    controller.dispose();if(!withdrawn&&reply==null)return;
    try{
      await LiveApi.call(withdrawn?'DELETE':'POST',
        '/irl/plans/'+Uri.encodeComponent(id)+'/interest',
        withdrawn?null:{'reply':reply??''});
      _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _delete(String id)async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Delete your IRL plan?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if(yes!=true)return;
    try{await LiveApi.call('DELETE','/irl/plans/'+Uri.encodeComponent(id));_load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _setLocation(String id,Map<String,dynamic> plan)async{
    final place=TextEditingController(text:field(plan,'place'));
    final url=TextEditingController(text:field(plan,'meetupUrl'));
    final data=await showDialog<Map<String,String>>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Set protected meetup location'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:place,maxLength:180,
          decoration:const InputDecoration(labelText:'Meetup place')),
        TextField(controller:url,maxLength:2048,
          decoration:const InputDecoration(labelText:'Google Maps HTTPS link')),
        const Text('Only approved attendees can see the meetup link.'),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{
          'place':place.text.trim(),'meetupUrl':url.text.trim(),
        }),child:const Text('Save'))]));
    place.dispose();url.dispose();if(data==null)return;
    try{await LiveApi.call('PATCH','/irl/plans/'+Uri.encodeComponent(id)+'/location',data);_load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _invite(String planId,String userId)async{
    try{
      await LiveApi.call('POST','/irl/plans/'+Uri.encodeComponent(planId)+
        '/invitations',{'recipientId':userId});
      _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _removeParticipant(String planId,String userId)async{
    try{
      await LiveApi.call('DELETE','/irl/plans/'+Uri.encodeComponent(planId)+
        '/participants/'+Uri.encodeComponent(userId));
      _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _openMaps(String link)async{
    try{
      final uri=Uri.tryParse(link);
      if(uri==null||uri.scheme!='https')throw const LiveApiError('Invalid Maps link.');
      if(!await launchUrl(uri,mode:LaunchMode.externalApplication)){
        throw const LiveApiError('No Maps app could open this location.');
      }
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context){
    final visible=plans.where((raw){
      final p=obj(raw);
      return (!mine||field(p,'creatorId')==myId)&&
        (filter=='All'||field(p,'category')==filter);
    }).toList();
    return Scaffold(appBar:AppBar(title:const Text('Blink IRL'),actions:[
      IconButton(onPressed:_create,tooltip:'Create IRL plan',
        icon:const Icon(Icons.add_circle_outline))]),
      body:loading?const Center(child:CircularProgressIndicator(color:BlinkColors.orange))
        :error.isNotEmpty?liveError(error,_load)
        :RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
          Row(children:[
            Expanded(child:DropdownButtonFormField<String>(initialValue:filter,
              decoration:const InputDecoration(labelText:'Category'),
              items:_irlCategories.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
              onChanged:(v){if(v!=null)setState(()=>filter=v);})),
            const SizedBox(width:10),
            FilterChip(label:const Text('My plans'),selected:mine,
              selectedColor:BlinkColors.orangeSoft,
              onSelected:(v)=>setState(()=>mine=v)),
          ]),
          if(visible.isEmpty)const ListTile(title:Text('No IRL plans in this category.')),
          ...visible.map((raw){
            final plan=obj(raw),id=field(plan,'id');
            final owner=field(plan,'creatorId')==myId;
            final interested=arr(plan['interests']).any((i)=>field(i,'userId')==myId);
            return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(field(plan,'title'),style:Theme.of(context).textTheme.titleLarge),
                Text(field(plan,'category')+' · '+field(plan,'place')),
                Text(field(plan,'description')),
                Text('Starts: '+field(plan,'startsAt')),
                if(field(plan,'meetupUrl').isNotEmpty)
                  TextButton.icon(onPressed:()=>_openMaps(field(plan,'meetupUrl')),
                    icon:const Icon(Icons.location_on_outlined),label:const Text('Google Maps location')),
                Wrap(spacing:8,children:[
                  if(!owner)TextButton(onPressed:()=>_interest(id,interested),
                    child:Text(interested?'Withdraw interest':'Interested')),
                  TextButton(onPressed:()=>Navigator.push<void>(context,MaterialPageRoute(
                    builder:(_)=>LiveIrlChatScreen(planId:id,title:field(plan,'title')))),
                    child:const Text('Private plan chat')),
                  if(owner)...[
                    TextButton(onPressed:()=>_setLocation(id,plan),child:const Text('Set location')),
                    TextButton(onPressed:()=>_delete(id),child:const Text('Delete')),
                  ],
                ]),
                if(owner&&arr(plan['interests']).isNotEmpty)...[
                  const Divider(),
                  const Text('Interested friends',style:TextStyle(fontWeight:FontWeight.w800)),
                  ...arr(plan['interests']).map((rawInterest){
                    final i=obj(rawInterest),userId=field(i,'userId');
                    final invited=arr(plan['invitations']).any((x)=>field(x,'recipientId')==userId);
                    return ListTile(title:Text(field(i['user'],'name','Friend')),
                      subtitle:Text(field(i,'reply')),
                      trailing:invited
                        ?IconButton(tooltip:'Remove participant',onPressed:()=>
                            _removeParticipant(id,userId),
                          icon:const Icon(Icons.person_remove_outlined))
                        :TextButton(onPressed:()=>_invite(id,userId),child:const Text('Invite')));
                  }),
                ],
              ])));
          }),
        ])),
    );
  }
}
