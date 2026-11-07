import 'dart:async';
import 'package:flutter/material.dart';
import '../core/blink_auth_api.dart';
import '../core/live_api.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Native Check-Ins: the same API contract, emoji choices and privacy as Blink web.
class LiveCheckinsScreen extends StatefulWidget {
  const LiveCheckinsScreen({super.key, this.openComposer = false});
  final bool openComposer;

  @override
  State<LiveCheckinsScreen> createState() => _CheckinsState();
}

class _CheckinsState extends State<LiveCheckinsScreen> {
  List<dynamic> items = [];
  Map<String, dynamic> mine = {};
  String? error;
  String myUserId = '';
  bool loading = true;
  bool busy = false;
  bool initialComposerOpened = false;
  String tab = 'all';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _active(dynamic value) {
    final expires = field(value, 'expiresAt');
    return expires.isEmpty ||
        (DateTime.tryParse(expires)?.isAfter(DateTime.now()) ?? false);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final result = await Future.wait([
        LiveApi.call('GET', '/checkins'),
        LiveApi.call('GET', '/checkins/mine'),
        BlinkAuthApi.cachedUser(),
      ]);
      if (!mounted) return;
      final own = obj(result[1]);
      final user = obj(result[2]);
      setState(() {
        items = arr(result[0]).where(_active).toList();
        mine = _active(own) ? own : {};
        myUserId = field(user, 'id', field(own, 'userId'));
        error = null;
        loading = false;
      });
      if (widget.openComposer && !initialComposerOpened) {
        initialComposerOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _compose();
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _duration(dynamic value) {
    final expire = DateTime.tryParse(field(value, 'expiresAt'));
    if (expire == null) return 'Until removed';
    final remaining = expire.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours > 0) {
      return remaining.inHours.toString() + 'h ' +
          (remaining.inMinutes % 60).toString() + 'm left';
    }
    return (remaining.inMinutes + 1).toString() + 'm left';
  }

  Future<void> _compose() async {
    if (busy) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _CheckinEditor(existing: mine)),
    );
    if (saved == true) await _load();
  }

  Future<void> _remove() async {
    final id = field(mine, 'id');
    if (id.isEmpty || busy) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: const Text('Remove your Check-In?'),
        content: const Text('Your friends will no longer see this update.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => busy = true);
    try {
      await LiveApi.call('DELETE', '/checkins/' + Uri.encodeComponent(id));
      await _load(silent: true);
      if (mounted) liveNotice(context, 'Check-In removed.');
    } catch (e) {
      if (mounted) liveNotice(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _privateReply(Map<String, dynamic> checkin, {String? reaction}) async {
    final friendId = field(checkin, 'userId');
    if (friendId.isEmpty || friendId == myUserId) return;
    final name = field(checkin['user'], 'name', 'friend');
    String? message = reaction;
    if (message == null) {
      final controller = TextEditingController();
      message = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: Text('Reply privately to ' + name),
        content: TextField(
          controller: controller, maxLength: 700, maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write a private message...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send reply')),
        ],
      ));
      controller.dispose();
    }
    if (message == null || message.trim().isEmpty) return;
    try {
      final opened = obj(await LiveApi.call('POST', '/inbox/conversations', {'friendId': friendId}));
      final id = field(opened, 'conversationId');
      if (id.isEmpty) throw const LiveApiError('Could not open the private chat.');
      final content = (reaction == null ? 'Replied to Check-In ' : 'Reacted to Check-In ') +
          field(checkin, 'emoji') + ' ' + field(checkin, 'status') + '\n' + message;
      await LiveApi.call('POST', '/inbox/conversations/' + Uri.encodeComponent(id) +
          '/messages', {'body': content});
      if (mounted) liveNotice(context, 'Private reply sent to ' + name);
    } catch (e) {
      if (mounted) liveNotice(context, e.toString());
    }
  }

  Future<void> _openCheckin(Map<String, dynamic> checkin) async {
    if (field(checkin, 'userId') == myUserId) {
      _compose();
      return;
    }
    await showModalBottomSheet<void>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(field(checkin['user'], 'name', 'Blink friend') + "'s Check-In",
            style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(field(checkin, 'emoji') + '  ' + field(checkin, 'status'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (field(checkin, 'note').isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 6), child: Text(field(checkin, 'note'))),
          const SizedBox(height: 18),
          Wrap(spacing: 8, children: ['❤️','😂','🔥','🥹','👍'].map((emoji) =>
            ActionChip(label: Text(emoji, style: const TextStyle(fontSize: 22)),
              onPressed: () {
                Navigator.pop(ctx);
                _privateReply(checkin, reaction: emoji);
              })).toList()),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () { Navigator.pop(ctx); _privateReply(checkin); },
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Reply privately in Blink Inbox'),
          )),
        ]),
      )),
    );
  }

  Widget _tile(Map<String, dynamic> item, {bool own = false}) {
    final user = obj(item['user']);
    return BlinkProCard(
      onTap:()=>_openCheckin(item),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: BlinkColors.orangeSoft,
                borderRadius: BorderRadius.circular(16)),
              child: Text(field(item, 'emoji', '🧡'), style: const TextStyle(fontSize: 27))),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(own ? 'Your active Check-In' : field(user, 'name', 'Blink friend'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_duration(item), style: const TextStyle(color: BlinkColors.orangeDark,
                fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
            if (own) PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? _compose() : _remove(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit Check-In')),
                PopupMenuItem(value: 'remove', child: Text('Remove Check-In')),
              ],
            ) else const Icon(Icons.chevron_right_rounded, color: BlinkColors.muted),
          ]),
          const SizedBox(height: 11),
          Text(field(item, 'status'), style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 17)),
          if (field(item, 'note').isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(field(item, 'note'), style: const TextStyle(
              color: BlinkColors.muted, fontSize: 13, height: 1.5))),
          if (!own) Padding(padding: const EdgeInsets.only(top: 11),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 15, color: BlinkColors.muted),
              const SizedBox(width: 5),
              const Text('Friends only', style: TextStyle(fontSize: 11,
                color: BlinkColors.muted)),
              const Spacer(),
              const Text('React or reply', style: TextStyle(fontWeight: FontWeight.w700,
                color: BlinkColors.orange, fontSize: 12)),
              const Icon(Icons.arrow_forward_ios, size: 12, color: BlinkColors.orange),
            ])),
        ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = items.where((raw) {
      if (!_active(raw)) return false;
      final own = field(raw, 'userId') == myUserId;
      return tab == 'all' || (tab == 'mine' ? own : !own);
    }).map(obj).toList();
    return Scaffold(
      appBar: AppBar(
        title: const BlinkLogo(),
        actions: [
          IconButton(onPressed: () => _load(), tooltip: 'Refresh Check-Ins',
            icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        error != null ? liveError(error, () => _load()) :
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
            physics: const AlwaysScrollableScrollPhysics(), children: [
            const Text('A LITTLE UPDATE, A LOT OF CONNECTION',
              style: TextStyle(color: BlinkColors.orange, fontSize: 10,
                letterSpacing: 1.3, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Check-Ins 🧡', style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 5),
            const Text('Let your friends know how you are feeling, right now.',
              style: TextStyle(color: BlinkColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            if (mine.isNotEmpty) _tile(mine, own: true)
            else SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _compose, icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create Check-In'))),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Text("Friends' updates", style: Theme.of(context).textTheme.titleLarge)),
              TextButton.icon(onPressed: () => _load(), icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Refresh')),
            ]),
            const SizedBox(height: 5),
            const Text('Only you and your friends can see your Check-Ins.',
              style: TextStyle(color: BlinkColors.muted, fontSize: 12)),
            const SizedBox(height: 14),
            BlinkAdaptiveSegments<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'friends', label: Text('Friends')),
                ButtonSegment(value: 'mine', label: Text('Mine')),
              ],
              selected: {tab},
              onChanged: (value) => setState(() => tab = value.first),
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                const Icon(Icons.favorite_border_rounded, color: BlinkColors.orange, size: 32),
                const SizedBox(height: 10),
                const Text('No active Check-Ins here yet.',
                  style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(tab == 'friends' ? 'Your friends can share what they are doing.'
                  : 'Start the conversation with a fresh Check-In.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BlinkColors.muted, fontSize: 12)),
              ]),
            ),
            ...visible.map((item) => _tile(item, own: field(item, 'userId') == myUserId)),
          ]),
        ),
      floatingActionButton: loading || error != null || mine.isNotEmpty
        ? null : FloatingActionButton.extended(
            onPressed: _compose, icon: const Icon(Icons.add),
            label: const Text('Check-In'), backgroundColor: BlinkColors.orange,
            foregroundColor: Colors.white),
    );
  }
}

class _CheckinEditor extends StatefulWidget {
  const _CheckinEditor({required this.existing});
  final Map<String, dynamic> existing;
  @override State<_CheckinEditor> createState() => _CheckinEditorState();
}

class _CheckinEditorState extends State<_CheckinEditor> {
  static const emojis = ['🧡','❤️','😊','🥹','🔥','✨','🌿','😴','🎉','💪','🫶','😂'];
  late final TextEditingController status;
  late final TextEditingController note;
  late String emoji;
  late String duration;
  bool submitting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    status = TextEditingController(text: field(widget.existing, 'status'));
    note = TextEditingController(text: field(widget.existing, 'note'));
    emoji = field(widget.existing, 'emoji', '🧡');
    duration = field(widget.existing, 'duration', '24h');
    if (!['24h', '48h', 'until_removed'].contains(duration)) duration = '24h';
  }
  @override void dispose() { status.dispose(); note.dispose(); super.dispose(); }

  Future<void> _publish() async {
    if (submitting || status.text.trim().isEmpty) return;
    setState(() { submitting = true; error = null; });
    try {
      final id = field(widget.existing, 'id');
      await LiveApi.call(id.isEmpty ? 'POST' : 'PATCH',
        id.isEmpty ? '/checkins' : '/checkins/' + Uri.encodeComponent(id), {
          'emoji': emoji, 'status': status.text.trim(), 'note': note.text.trim(),
          'duration': duration,
        });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.existing.isNotEmpty;
    return BlinkCreateLayout(
      title: edit ? 'Edit Check-In' : 'New Check-In',
      subtitle: 'Share a little about your day with your Blink friends.',
      icon: Icons.waving_hand_outlined,
      busy: submitting,
      primaryLabel: submitting ? 'Saving...' :
          edit ? 'Save Check-In' : 'Publish Check-In',
      onSubmit: status.text.trim().isEmpty ? null : _publish,
      content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BlinkFormSection(
          heading: 'Your update',
          helper: 'A simple status helps your friends know how you feel.',
          children: [
            TextField(
              controller: status,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'What is on your mind?',
                hintText: 'Write a short status...',
              ),
            ),
            const SizedBox(height: 12),
            const Text('How are you feeling?',
              style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 9, children: emojis.map((choice) =>
              InkWell(
                onTap: submitting ? null : () => setState(() => emoji = choice),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 49, height: 49,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: emoji == choice
                        ? BlinkColors.orangeSoft : Colors.white,
                    border: Border.all(
                      color: emoji == choice
                          ? BlinkColors.orange : BlinkColors.line,
                      width: emoji == choice ? 2 : 1),
                    borderRadius: BorderRadius.circular(14)),
                  child: Text(choice, style: const TextStyle(fontSize: 25)),
                ),
              ),
            ).toList()),
            const SizedBox(height: 18),
            TextField(
              controller: note, maxLength: 280, maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'A little more (optional)',
                alignLabelWithHint: true,
                hintText: 'Tell your friends a little more...',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        BlinkFormSection(
          heading: 'Visibility',
          helper: 'Choose how long your friends can see this Check-In.',
          children: [
            DropdownButtonFormField<String>(
              initialValue: duration, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Visible for'),
              items: const [
                DropdownMenuItem(value: '24h', child: Text('24 hours')),
                DropdownMenuItem(value: '48h', child: Text('48 hours')),
                DropdownMenuItem(value: 'until_removed',
                  child: Text('Until I remove it')),
              ],
              onChanged: submitting ? null : (value) {
                if (value != null) setState(() => duration = value);
              },
            ),
            const SizedBox(height: 12),
            const Row(children: [
              Icon(Icons.lock_outline, color: BlinkColors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Visible to your Blink friends only.',
                style: TextStyle(color: BlinkColors.muted, fontSize: 12))),
            ]),
          ],
        ),
        if (error != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      ]),
    );
  }
}


class LiveSecretsScreen extends StatefulWidget{
  const LiveSecretsScreen({super.key});
  @override State<LiveSecretsScreen> createState()=>_SecretsState();
}
class _SecretsState extends State<LiveSecretsScreen>{
  List<dynamic> secrets=[];String? error;bool loading=true;
  String filter='all';
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final rows=arr(await LiveApi.call('GET','/secrets'));
      if(mounted)setState((){secrets=rows;error=null;loading=false;});
    }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _create([Map<String,dynamic>? existing])async{
    final edit=existing!=null;
    final prompt=TextEditingController(text:field(existing,'prompt'));
    final options=TextEditingController(text:arr(existing == null ? null : existing['options']).join('\n'));
    int correct=existing != null && existing['correctIndex'] is int
      ?existing['correctIndex'] as int:0;
    bool anonymous=field(existing,'visibility','ANONYMOUS')!='NAMED';
    int hours=24;
    final data=await showDialog<Map<String,dynamic>>(context:context,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>BlinkFormDialog(
        title:edit?'Edit Blink Secret':'Create Blink Secret',
        subtitle:'Ask a question with a timed answer reveal.',
        icon:Icons.help_outline_rounded,
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:prompt,maxLength:500,maxLines:3,
            textCapitalization:TextCapitalization.sentences,
            decoration:const InputDecoration(labelText:'Your question',alignLabelWithHint:true)),
          const SizedBox(height:12),
          TextField(controller:options,maxLines:5,
            decoration:const InputDecoration(labelText:'Answer options (2–5, one per line)',alignLabelWithHint:true)),
          const SizedBox(height:12),
          DropdownButtonFormField<int>(initialValue:correct,isExpanded:true,
            decoration:const InputDecoration(labelText:'Correct answer position'),
            items:List.generate(5,(i)=>DropdownMenuItem(value:i,
              child:Text('Option '+(i+1).toString()))),
            onChanged:(v){if(v!=null)update(()=>correct=v);}),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Anonymous Secret'),value:anonymous,
            activeTrackColor:BlinkColors.orange,
            onChanged:(v)=>update(()=>anonymous=v)),
          if(!edit)DropdownButtonFormField<int>(initialValue:hours,isExpanded:true,
            decoration:const InputDecoration(labelText:'Reveal answers after'),
            items:const [
              DropdownMenuItem(value:1,child:Text('1 hour')),
              DropdownMenuItem(value:24,child:Text('24 hours')),
              DropdownMenuItem(value:48,child:Text('48 hours')),
              DropdownMenuItem(value:72,child:Text('72 hours')),
              DropdownMenuItem(value:168,child:Text('7 days')),
            ],onChanged:(v){if(v!=null)update(()=>hours=v);}),
          if(edit)const Text('The existing reveal time stays unchanged.',
            style:TextStyle(fontSize:12,color:BlinkColors.muted)),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:(){
            final opts=options.text.split('\n').map((x)=>x.trim())
              .where((x)=>x.isNotEmpty).toList();
            if(prompt.text.trim().length<5||opts.length<2||opts.length>5||
              correct>=opts.length){
              liveNotice(ctx,'Enter a valid question, 2–5 answers and the correct position.');
              return;
            }
            Navigator.pop(ctx,{
              'prompt':prompt.text.trim(),'options':opts,'correctIndex':correct,
              'visibility':anonymous?'ANONYMOUS':'NAMED',
              if(!edit)'revealAt':DateTime.now().toUtc()
                .add(Duration(hours:hours)).toIso8601String(),
            });
          },child:Text(edit?'Save':'Publish')),
        ],
      )));
    prompt.dispose();options.dispose();
    if(data==null)return;
    try{
      await LiveApi.call(edit?'PATCH':'POST',
        edit?'/secrets/'+Uri.encodeComponent(field(existing,'id')):'/secrets',data);
      await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _act(String path,Map<String,dynamic> data)async{
    try{await LiveApi.call('POST',path,data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context){
    final visible=secrets.where((raw){
      final s=obj(raw);
      return filter=='all'||(filter=='mine'&&s['isMine']==true)||
        (filter=='answered'&&s['myGuess']!=null);
    }).toList();
    return Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Blink Secrets'),actions:[
      IconButton(onPressed:()=>_create(),tooltip:'Create Secret',
        icon:const Icon(Icons.add_circle_outline)),
    ]),body:loading?const Center(child:CircularProgressIndicator(color:BlinkColors.orange))
      :error!=null?liveError(error,_load)
      :RefreshIndicator(onRefresh:_load,child:ListView(
        padding:const EdgeInsets.all(12),children:[
          BlinkAdaptiveSegments<String>(segments:const [
            ButtonSegment(value:'all',label:Text('Explore')),
            ButtonSegment(value:'mine',label:Text('My Secrets')),
            ButtonSegment(value:'answered',label:Text('Answered')),
          ],selected:{filter},onChanged:(values)=>
            setState(()=>filter=values.first)),
          const SizedBox(height:12),
          if(visible.isEmpty)const ListTile(title:Text('No Secrets found for this tab.')),
          ...visible.map((raw){
            final item=obj(raw),id=field(item,'id'),selected=item['myGuess'];
            final choices=arr(item['options']),reveal=item['revealed']==true;
            final own=item['isMine']==true;
            return BlinkProCard(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:45,height:45,decoration:BoxDecoration(
                    color:BlinkColors.orangeSoft,borderRadius:BorderRadius.circular(14)),
                    child:const Icon(Icons.lock_open_outlined,color:BlinkColors.orangeDark)),
                  const SizedBox(width:11),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('BLINK SECRET · '+(own?'YOUR QUESTION':'DISCOVER'),
                      style:const TextStyle(fontSize:10,letterSpacing:.7,
                        color:BlinkColors.orangeDark,fontWeight:FontWeight.w800)),
                    const SizedBox(height:4),
                    Text(field(item,'prompt'),maxLines:5,overflow:TextOverflow.ellipsis,
                      style:Theme.of(context).textTheme.titleMedium),
                  ])),
                  if(item['canEdit']==true)IconButton(
                    tooltip:'Edit your Secret',icon:const Icon(Icons.edit_outlined,
                      color:BlinkColors.orange),onPressed:()=>_create(item)),
                ]),
                const SizedBox(height:12),
                Wrap(spacing:7,runSpacing:7,children:[
                  BlinkInfoPill(own?'Your Secret':field(item['author'],'name','Anonymous'),
                    icon:Icons.person_outline_rounded,highlight:true),
                  BlinkInfoPill(reveal?'Revealed':'Reveal scheduled',
                    icon:Icons.schedule_outlined),
                ]),
                const SizedBox(height:10),
                ...choices.asMap().entries.map((entry)=>RadioListTile<int>(
                  title:Text(entry.value.toString()),
                  value:entry.key,groupValue:selected is int?selected:null,
                  onChanged:own||selected!=null||reveal?null:(index){
                    if(index!=null)_act('/secrets/'+Uri.encodeComponent(id)+'/guess',
                      {'selectedIndex':index});
                  })),
                if(reveal||own)Text('Correct answer: '+
                  (item['correctIndex'] is int
                    ?'Option '+((item['correctIndex'] as int)+1).toString()
                    :'Pending'),
                  style:const TextStyle(fontWeight:FontWeight.w700)),
                if(!reveal)Text('Reveals: '+field(item,'revealAt')),
                Wrap(spacing:7,children:['🧡','❤️','😮','😂','👏'].map((emoji)=>TextButton(
                  onPressed:()=>_act('/secrets/'+Uri.encodeComponent(id)+'/react',
                    {'emoji':emoji}),child:Text(emoji))).toList()),
                Text(field(item,'guessCount','0')+' guesses · Earned '+
                  field(item,'myReward','0')+' BP'),
              ]));
          }),
        ])),
    );
  }
}

class LiveHeartsScreen extends StatefulWidget{
  const LiveHeartsScreen({super.key});
  @override State<LiveHeartsScreen> createState()=>_HeartsState();
}
class _HeartsState extends State<LiveHeartsScreen>{
  List<dynamic> incoming=[],sent=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final results=await Future.wait([LiveApi.call('GET','/hearts/incoming'),LiveApi.call('GET','/hearts/sent')]);
      if(mounted)setState((){incoming=arr(results[0]);sent=arr(results[1]);error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _send()async{
    final search=TextEditingController();final message=TextEditingController();
    List<dynamic> found=[];String? selectedId;
    final data=await showDialog<Map<String,String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>BlinkFormDialog(
      title:'Send an anonymous Heart',
      subtitle:'Choose a Blink member and write a private note.',
      icon:Icons.favorite_border_rounded,
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:search,decoration:InputDecoration(labelText:'Find member',
          suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:()async{
            try{final r=arr(await LiveApi.call('GET','/hearts/people?search=${Uri.encodeQueryComponent(search.text.trim())}'));
              if(ctx.mounted)update(()=>found=r);
            }catch(e){if(ctx.mounted)liveNotice(ctx,e.toString());}
          }))),
        const SizedBox(height:12),
        ...found.map((u)=>RadioListTile<String>(title:Text(field(u,'name')),value:field(u,'id'),
          groupValue:selectedId,onChanged:(v)=>update(()=>selectedId=v))),
        TextField(controller:message,maxLines:4,maxLength:2000,
          textCapitalization:TextCapitalization.sentences,
          onChanged:(_)=>update((){}),
          decoration:const InputDecoration(labelText:'Your private Heart message',alignLabelWithHint:true)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:selectedId==null||message.text.trim().isEmpty?null:()=>Navigator.pop(ctx,{'receiverId':selectedId!,'text':message.text.trim()}),
          child:const Text('Send Heart'))],
    )));
    search.dispose();message.dispose();
    if(data==null)return;
    try{await LiveApi.call('POST','/hearts',data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const BlinkBrandedTitle('Blink Hearts'),actions:[
      IconButton(tooltip:'Send Heart',onPressed:_send,icon:const Icon(Icons.favorite_border))]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
      const ListTile(title:Text('Received Hearts',style:TextStyle(fontWeight:FontWeight.bold))),
      ...incoming.map((x)=>_heartTile(x)),
      const Divider(),
      const ListTile(title:Text('Sent Hearts',style:TextStyle(fontWeight:FontWeight.bold))),
      ...sent.map((x)=>_heartTile(x)),
      if(incoming.isEmpty&&sent.isEmpty)const ListTile(title:Text('No Hearts yet')),
    ])),
  );
  Widget _heartTile(dynamic value){final heart=obj(value);final id=field(heart,'id');
    return BlinkProListCard(
      icon:Icons.favorite_border_rounded,
      eyebrow:heart['side']=='incoming'?'RECEIVED HEART':'SENT HEART',
      title:field(heart['person'],'name',heart['side']=='incoming'?'Anonymous sender':'Blink member'),
      subtitle:heart['side']=='incoming'
        ?'A private note from a Blink member':'Your personal Heart conversation',
      badges:[BlinkInfoPill(field(heart,'status','PENDING'),
        icon:Icons.favorite_outline,highlight:true)],
      onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
        builder:(_)=>LiveHeartThreadScreen(id:id))).then((_){_load();}),
    );
  }
}

class LiveHeartThreadScreen extends StatefulWidget{
  final String id;
  const LiveHeartThreadScreen({super.key,required this.id});
  @override State<LiveHeartThreadScreen> createState()=>_HeartThreadState();
}
class _HeartThreadState extends State<LiveHeartThreadScreen>{
  final message=TextEditingController();Map<String,dynamic> data={};String? error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){message.dispose();super.dispose();}
  Future<void> _load()async{
    try{final r=obj(await LiveApi.call('GET','/hearts/${Uri.encodeComponent(widget.id)}'));
      if(mounted)setState((){data=r;error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> _action(String suffix,[Map<String,dynamic>? body])async{
    try{await LiveApi.call('POST','/hearts/${widget.id}/$suffix',body);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }

  Future<void> _editMessage(dynamic raw)async{
    final item=obj(raw),id=field(item,'id');
    if(id.isEmpty||item['fromMe']!=true)return;
    final controller=TextEditingController(text:field(item,'text'));
    final edited=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Edit Heart message'),
      content:TextField(controller:controller,maxLength:2000,maxLines:4,
        decoration:const InputDecoration(labelText:'Your Heart message')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Save'))]));
    controller.dispose();
    if(edited==null||edited.isEmpty)return;
    try{
      await LiveApi.call('PATCH','/hearts/'+Uri.encodeComponent(widget.id)+
        '/messages/'+Uri.encodeComponent(id),{'text':edited});
      await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Heart conversation')),body:Column(children:[
    if(error!=null)liveError(error,_load),
    if(data['side']=='incoming'&&data['status']=='PENDING')
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        TextButton(onPressed:()=>_action('respond',{'status':'ACCEPTED'}),child:const Text('Accept')),
        TextButton(onPressed:()=>_action('respond',{'status':'DECLINED'}),child:const Text('Decline')),
      ]),
    if(data['side']=='sent'&&data['revealed']!=true)
      TextButton(onPressed:()=>_action('reveal'),child:const Text('Reveal my identity')),
    if(data['side']=='incoming'&&data['blockedByMe']!=true)
      TextButton(onPressed:()=>_action('block'),child:const Text('Block sender')),
    Expanded(child:ListView(padding:const EdgeInsets.all(15),children:arr(data['messages']).map((m)=>Card(
      child:ListTile(title:Text(field(m,'text')),
        subtitle:obj(m)['editedAt']!=null?const Text('Edited'):null,
        trailing:obj(m)['fromMe']==true?IconButton(
          tooltip:'Edit Heart message',onPressed:()=>_editMessage(m),
          icon:const Icon(Icons.edit_outlined,color:BlinkColors.orange)):null))).toList())),
    SafeArea(top:false,child:Row(children:[
      Expanded(child:TextField(controller:message,decoration:const InputDecoration(hintText:'Write a Heart reply...'))),
      IconButton(onPressed:()async{if(message.text.trim().isEmpty)return;
        await _action('messages',{'text':message.text.trim()});message.clear();},
        icon:const Icon(Icons.send,color:BlinkColors.orange)),
    ])),
  ]));
}

class LiveIrlScreen extends StatefulWidget{
  const LiveIrlScreen({super.key});
  @override State<LiveIrlScreen> createState()=>_IrlState();
}
class _IrlState extends State<LiveIrlScreen>{
  List<dynamic> plans=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{try{final r=arr(await LiveApi.call('GET','/irl/plans'));
      if(mounted)setState((){plans=r;error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}}
  Future<void> _create()async{
    final title=TextEditingController(),desc=TextEditingController(),place=TextEditingController();
    var start=DateTime.now().add(const Duration(days:1));var category='Hangout';
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('Create IRL plan'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Title')),
        TextField(controller:desc,decoration:const InputDecoration(labelText:'Description')),
        TextField(controller:place,decoration:const InputDecoration(labelText:'Place')),
        DropdownButton<String>(value:category,isExpanded:true,items:['Hangout','Sports','Gaming','Food','Shopping','Other']
          .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)update(()=>category=v);}),
        TextButton.icon(icon:const Icon(Icons.event),label:Text('Starts: ${start.toLocal()}'),
          onPressed:()async{final d=await showDatePicker(context:ctx,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:start);
            if(d==null||!ctx.mounted)return;
            final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(start));
            if(t!=null)update(()=>start=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{'title':title.text,'category':category,
          'description':desc.text,'place':place.text,'startsAt':start.toUtc().toIso8601String()}),
          child:const Text('Create'))],
    )));
    title.dispose();desc.dispose();place.dispose();
    if(data==null)return;
    try{await LiveApi.call('POST','/irl/plans',data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _interest(String id)async{
    try{await LiveApi.call('POST','/irl/plans/$id/interest',{'reply':'Interested in joining'});await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const BlinkBrandedTitle('IRL Plans'),actions:[
      IconButton(tooltip:'Create plan',onPressed:_create,icon:const Icon(Icons.add))]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
      RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
        if(plans.isEmpty)const ListTile(title:Text('No plans from your Blink friends yet.')),
        ...plans.map((p){final plan=obj(p);final id=field(plan,'id');
          return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(field(plan,'title'),style:Theme.of(context).textTheme.titleMedium),
            Text(field(plan,'category')+' · '+field(plan,'place')),
            Text(field(plan,'description')),
            Text('Starts: ${field(plan,'startsAt')}'),
            Wrap(children:[
              TextButton(onPressed:()=>_interest(id),child:const Text('Interested')),
              TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(
                builder:(_)=>LiveIrlChatScreen(planId:id,title:field(plan,'title')))),
                child:const Text('Plan chat')),
            ]),
          ])));
        }),
      ])),
  );
}

class LiveIrlChatScreen extends StatefulWidget{
  final String planId,title;
  const LiveIrlChatScreen({super.key,required this.planId,required this.title});
  @override State<LiveIrlChatScreen> createState()=>_IrlChatState();
}
class _IrlChatState extends State<LiveIrlChatScreen>{
  final text=TextEditingController();List<dynamic> messages=[];String? error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){text.dispose();super.dispose();}
  Future<void> _load()async{try{final data=obj(await LiveApi.call('GET','/irl/plans/${widget.planId}/messages'));
      if(mounted)setState((){messages=arr(data['messages']);error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}}
  Future<void> _send()async{
    try{await LiveApi.call('POST','/irl/plans/${widget.planId}/messages',{'text':text.text.trim()});
      text.clear();await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:BlinkBrandedTitle(widget.title)),body:Column(children:[
    if(error!=null)liveError(error,_load),
    Expanded(child:ListView(children:messages.map((m)=>ListTile(
      title:Text(field(obj(m)['sender'],'name','Blink member')),subtitle:Text(field(m,'text')))).toList())),
    SafeArea(top:false,child:Row(children:[Expanded(child:TextField(controller:text,decoration:const InputDecoration(hintText:'Message...'))),
      IconButton(onPressed:_send,icon:const Icon(Icons.send,color:BlinkColors.orange))])),
  ]));
}
