import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/blink_auth_api.dart';
import '../core/live_api.dart';
import '../core/theme.dart';

const _exchangeKinds = <String>['OFFER', 'REQUEST', 'ADVICE', 'COLLABORATION'];
const _exchangeCurrencies = <String>['BDT','USD','EUR','GBP','INR','AED','SAR','CAD','AUD','SGD'];

Future<dynamic> _exchangeMultipart(String method, String path,
    Map<String, String> values, List<XFile> images) async {
  final token = await BlinkAuthApi.getToken();
  if (token == null || token.isEmpty) throw const LiveApiError('Please sign in again.');
  final request = http.MultipartRequest(method, Uri.parse(LiveApi.root + path));
  request.headers['Authorization'] = 'Bearer $token';
  request.fields.addAll(values);
  for (final image in images.take(4)) {
    final name = image.name.toLowerCase();
    final subtype = name.endsWith('.png') ? 'png' : name.endsWith('.webp') ? 'webp' : 'jpeg';
    request.files.add(await http.MultipartFile.fromPath('files', image.path,
        contentType: MediaType('image', subtype)));
  }
  final stream = await request.send().timeout(const Duration(minutes: 3));
  final response = await http.Response.fromStream(stream);
  dynamic data;
  try { data = jsonDecode(response.body); } catch (_) { data = null; }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw LiveApiError(data is Map
        ? (data['message'] is List ? (data['message'] as List).join(', ') : (data['message'] ?? 'Save failed').toString())
        : 'Save failed (HTTP ' + response.statusCode.toString() + ')');
  }
  return data;
}

class FullExchangeScreen extends StatefulWidget {
  const FullExchangeScreen({super.key});
  @override State<FullExchangeScreen> createState() => _FullExchangeScreenState();
}
class _FullExchangeScreenState extends State<FullExchangeScreen> {
  final search = TextEditingController();
  String kind = '', error = '', userId = '';
  bool mine = false, loading = true;
  int page = 1, pages = 1;
  List<dynamic> posts = [];
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<void> _load({int? next}) async {
    if (next != null) page = next;
    setState(() { loading = true; error = ''; });
    try {
      final params = <String, String>{'page': '$page'};
      if (search.text.trim().isNotEmpty) params['search'] = search.text.trim();
      if (kind.isNotEmpty) params['kind'] = kind;
      if (mine) params['mine'] = 'true';
      final response = obj(await LiveApi.call('GET',
          '/Exchange?' + Uri(queryParameters: params).query));
      final user = await BlinkAuthApi.cachedUser();
      if (!mounted) return;
      setState(() {
        userId = field(user, 'id');
        posts = arr(response['items']);
        pages = int.tryParse(field(response, 'pages', '1')) ?? 1;
        loading = false;
      });
    } catch (e) { if (mounted) setState(() { loading = false; error = e.toString(); }); }
  }

  Future<void> _openEditor([Map<String, dynamic>? post]) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => FullExchangeEditor(post: post)));
    if (changed == true) _load(next: 1);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BlinkBrandedTitle('Blink Exchange'), actions: [
      IconButton(tooltip: 'Create an Exchange post', icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _openEditor()),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        TextField(controller: search, textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: 'Search services, skills and requests',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
              onPressed: () => _load(next: 1))),
          onSubmitted: (_) => _load(next: 1)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final categories = DropdownButtonFormField<String>(
            key: ValueKey(kind),
            initialValue: kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Service type'),
            items: [const DropdownMenuItem(value: '', child: Text('All types')),
              ..._exchangeKinds.map((k) => DropdownMenuItem(value: k,
                child: Text(k, overflow: TextOverflow.ellipsis)))],
            onChanged: (v) { kind = v ?? ''; _load(next: 1); },
          );
          final own = FilterChip(label: const Text('My posts'), selected: mine,
            selectedColor: BlinkColors.orangeSoft,
            onSelected: (v) { mine = v; _load(next: 1); });
          if (constraints.maxWidth < 380) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              categories,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: own),
            ]);
          }
          return Row(children: [
            Expanded(child: categories),
            const SizedBox(width: 10),
            own,
          ]);
        }),
      ])),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator(color: BlinkColors.orange))
        : error.isNotEmpty ? liveError(error, () => _load())
        : RefreshIndicator(onRefresh: _load, child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            const BlinkFeatureHero(
              eyebrow:'SKILLS · SERVICES · POSSIBILITIES',
              title:'Make a better exchange.',
              subtitle:'Connect over real skills, negotiate privately and discover your next collaboration.',
              icon:Icons.handshake_rounded,
              mood:BlinkMood.exchange,
              margin:EdgeInsets.fromLTRB(0,0,0,18),
            ),
            if (posts.isEmpty) const Padding(padding: EdgeInsets.all(28),
              child: Center(child: Text('No Exchange posts found.'))),
            ...posts.map((raw) {
              final p = obj(raw), own = field(p, 'authorId') == userId;
              return BlinkProListCard(
                icon:own ? Icons.workspace_premium_rounded : Icons.handshake_rounded,
                eyebrow:own ? 'YOUR EXCHANGE POST' : 'BLINK EXCHANGE',
                title:field(p,'title'),
                subtitle:field(p,'description'),
                badges:[
                  BlinkInfoPill(field(p,'kind','OFFER'),icon:Icons.swap_horiz_rounded,
                    highlight:true),
                  BlinkInfoPill(field(p,'status','OPEN'),
                    icon:Icons.circle_outlined),
                  if(field(p['author'],'name').isNotEmpty)
                    BlinkInfoPill(field(p['author'],'name'),
                      icon:Icons.account_circle_outlined),
                ],
                trailing:own ? IconButton(
                  tooltip:'Edit my post',icon:const Icon(Icons.edit_outlined,
                    color:BlinkColors.orangeDark),onPressed:()=>_openEditor(p)) : null,
                footer:const Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                  Text('Open negotiation',style:TextStyle(
                    color:BlinkColors.orangeDark,fontWeight:FontWeight.w800)),
                  SizedBox(width:6),Icon(Icons.arrow_forward_rounded,
                    color:BlinkColors.orangeDark,size:18),
                ]),
                onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
                  builder:(_)=>FullExchangeDetail(id:field(p,'id')))).then((_){_load();}),
              );
            }),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: page > 1 ? () => _load(next: page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
              Text('Page $page / $pages'),
              IconButton(onPressed: page < pages ? () => _load(next: page + 1) : null,
                icon: const Icon(Icons.chevron_right)),
            ]),
          ],
        ))),
    ]),
  );
}

class FullExchangeEditor extends StatefulWidget {
  const FullExchangeEditor({super.key, this.post});
  final Map<String, dynamic>? post;
  @override State<FullExchangeEditor> createState() => _FullExchangeEditorState();
}
class _FullExchangeEditorState extends State<FullExchangeEditor> {
  late final title = TextEditingController(text: field(widget.post, 'title'));
  late final description = TextEditingController(text: field(widget.post, 'description'));
  late String kind = field(widget.post, 'kind', 'OFFER');
  late String status = field(widget.post, 'status', 'OPEN');
  List<XFile> images = [];
  bool busy = false;
  @override void dispose() { title.dispose(); description.dispose(); super.dispose(); }

  Future<void> _pick() async {
    try {
      final selected = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (selected.length > 4 && mounted) liveNotice(context, 'Maximum 4 images; first four selected.');
      if (mounted) setState(() => images = selected.take(4).toList());
    } catch (e) { if (mounted) liveNotice(context, 'Could not choose images: $e'); }
  }

  Future<void> _save() async {
    if (busy) return;
    if (title.text.trim().length < 6 || description.text.trim().length < 20) {
      liveNotice(context, 'Title needs 6 characters and description needs 20 characters.');
      return;
    }
    setState(() => busy = true);
    try {
      final id = field(widget.post, 'id');
      await _exchangeMultipart(id.isEmpty ? 'POST' : 'PATCH',
        id.isEmpty ? '/Exchange' : '/Exchange/' + Uri.encodeComponent(id), {
          'title': title.text.trim(),
          'description': description.text.trim(),
          'kind': kind,
          if (id.isNotEmpty) 'status': status,
        }, images);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => BlinkCreateLayout(
    title: widget.post == null ? 'Create Exchange Post' : 'Edit Exchange Post',
    subtitle: 'Describe your offer clearly so the right people can respond.',
    icon: Icons.swap_horiz_rounded,
    busy: busy,
    primaryLabel: busy ? 'Saving Exchange...' : 'Save Exchange Post',
    onSubmit: _save,
    content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BlinkFormSection(
        heading: 'Post details',
        helper: 'A short title and useful details help others understand the exchange.',
        children: [
          TextField(
            controller: title,
            maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Post title', hintText: 'What are you offering or looking for?',
              prefixIcon: Icon(Icons.title_rounded)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: description,
            minLines: 4, maxLines: 8, maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description', alignLabelWithHint: true,
              hintText: 'Explain what you offer or need...'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: kind, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Exchange type'),
            items: _exchangeKinds.map((k) =>
              DropdownMenuItem(value: k, child: Text(k,
                overflow: TextOverflow.ellipsis))).toList(),
            onChanged: busy ? null : (v) {
              if (v != null) setState(() => kind = v);
            },
          ),
          if (widget.post != null) ...[
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: status, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Post status'),
              items: ['OPEN', 'CLOSED'].map((k) =>
                DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: busy ? null : (v) {
                if (v != null) setState(() => status = v);
              },
            ),
          ],
        ],
      ),
      const SizedBox(height: 16),
      BlinkFormSection(
        heading: 'Photos',
        helper: 'Attach up to 4 images. Clear photos help people understand your post.',
        children: [
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: busy ? null : _pick,
            label: Text('Choose photos (${images.length}/4)'),
          )),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 9),
            ...images.map((im) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined, color: BlinkColors.orange),
              title: Text(im.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Remove photo',
                icon: const Icon(Icons.close_rounded),
                onPressed: busy ? null : () => setState(() => images.remove(im)),
              ),
            )),
          ],
          if (widget.post != null) const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Choosing new photos will replace existing images.',
              style: TextStyle(fontSize: 12, color: BlinkColors.muted)),
          ),
        ],
      ),
    ]),
  );
}

class FullExchangeDetail extends StatefulWidget {
  const FullExchangeDetail({super.key, required this.id});
  final String id;
  @override State<FullExchangeDetail> createState() => _FullExchangeDetailState();
}
class _FullExchangeDetailState extends State<FullExchangeDetail> {
  Map<String, dynamic> post = {};
  List<dynamic> threads = [];
  String myId = '', error = '';
  bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final data = obj(await LiveApi.call('GET', '/Exchange/' + Uri.encodeComponent(widget.id)));
      final user = await BlinkAuthApi.cachedUser();
      final currentId = field(user, 'id');
      List<dynamic> rows = [];
      if (field(data, 'authorId') == currentId) {
        rows = arr(await LiveApi.call('GET', '/Exchange/' + Uri.encodeComponent(widget.id) + '/chats'));
      }
      if (mounted) setState(() {
        post = data; myId = currentId; threads = rows; loading = false; error = '';
      });
    } catch (e) { if (mounted) setState(() { loading = false; error = e.toString(); }); }
  }
  Future<void> _delete() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete this Exchange post?'),
      content: const Text('The post, conversations and offers may be removed permanently.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (yes != true) return;
    try {
      await LiveApi.call('DELETE', '/Exchange/' + Uri.encodeComponent(widget.id));
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
  }
  Future<void> _startChat() async {
    try {
      final base = '/Exchange/' + Uri.encodeComponent(widget.id) + '/chats';
      var result = obj(await LiveApi.call('GET', base + '/mine'));
      var id = field(result, 'threadId');
      if (id.isEmpty) {
        result = obj(await LiveApi.call('POST', base));
        id = field(result, 'threadId');
      }
      if (id.isEmpty) throw const LiveApiError('Could not start negotiation.');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => FullExchangeThread(postId: widget.id, threadId: id,
          owner: false, title: field(post, 'title'))));
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
  }
  Future<void> _respond() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reply to Exchange post'),
      content: TextField(controller: controller, maxLines: 4,
        decoration: const InputDecoration(labelText: 'Your response')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Send'))]));
    controller.dispose();
    if (text == null || text.isEmpty) return;
    try {
      await LiveApi.call('POST', '/Exchange/' + Uri.encodeComponent(widget.id) + '/responses',
        {'message': text});
      _load();
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
  }
  Future<void> _ack(String id) async {
    try {
      await LiveApi.call('PATCH', '/Exchange/' + Uri.encodeComponent(widget.id) +
          '/responses/' + Uri.encodeComponent(id) + '/acknowledge');
      _load();
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
  }
  @override Widget build(BuildContext context) {
    final owner = myId.isNotEmpty && field(post, 'authorId') == myId;
    return Scaffold(appBar: AppBar(title: const BlinkBrandedTitle('Exchange Details'), actions: [
      if (owner) IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () async {
        final changed = await Navigator.push<bool>(context,
          MaterialPageRoute(builder: (_) => FullExchangeEditor(post: post)));
        if (changed == true) _load();
      }),
      if (owner) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
    ]), body: loading ? const Center(child: CircularProgressIndicator())
      : error.isNotEmpty ? liveError(error, _load)
      : RefreshIndicator(onRefresh: _load, child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BlinkFeatureHero(
            eyebrow:'BLINK EXCHANGE · DISCOVER',
            title:field(post,'title'),
            subtitle:'A space for skills, ideas and honest collaboration.',
            icon:Icons.handshake_rounded,
            mood:BlinkMood.exchange,
            margin:const EdgeInsets.fromLTRB(0,0,0,15),
          ),
          Wrap(spacing:8,runSpacing:8,children:[
            BlinkInfoPill(field(post,'kind','Service'),
              icon:Icons.swap_horiz_rounded,highlight:true),
            BlinkInfoPill(field(post,'status','OPEN'),
              icon:Icons.verified_outlined),
            BlinkInfoPill(field(post['author'],'name','Blink member'),
              icon:Icons.account_circle_outlined),
          ]),
          const SizedBox(height:16),
          BlinkProCard(
            mood:BlinkMood.exchange,
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('ABOUT THIS EXCHANGE',style:TextStyle(
                fontSize:10,letterSpacing:1.2,fontWeight:FontWeight.w900,
                color:BlinkColors.orangeDark)),
              const SizedBox(height:10),
              Text(field(post,'description'),
                style:const TextStyle(color:BlinkColors.ink,height:1.55)),
            ]),
          ),
          if (arr(post['media']).isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(height: 150, child: ListView(scrollDirection: Axis.horizontal, children: [
              ...arr(post['media']).map((m) => Padding(padding: const EdgeInsets.only(right: 9),
                child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.network(LiveApi.root + '/Exchange/media/' +
                    Uri.encodeComponent(field(m, 'id')),
                    width: 170, height: 150, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 170,
                      child: Icon(Icons.broken_image_outlined)))))) ,
            ])),
          ],
          const SizedBox(height: 18),
          if (!owner) ...[
            FilledButton.icon(onPressed: _startChat, icon: const Icon(Icons.forum_outlined),
              label: const Text('Open private negotiation')),
            OutlinedButton.icon(onPressed: _respond, icon: const Icon(Icons.reply_outlined),
              label: const Text('Send public response')),
          ],
          if (owner) ...[
            Text('Interested people (' + threads.length.toString() + ')',
              style: Theme.of(context).textTheme.titleLarge),
            ...threads.map((r) => BlinkProListCard(
              icon:Icons.forum_outlined,
              eyebrow:'PRIVATE NEGOTIATION',
              title:field(r['requester'],'name','Interested user'),
              subtitle:field(r,'updatedAt'),
              mood:BlinkMood.exchange,
              onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
                builder:(_)=>FullExchangeThread(postId:widget.id,
                  threadId:field(r,'id'),title:field(post,'title'),owner:true))),
            )),
          ],
          const Divider(height: 32),
          Text('Responses', style: Theme.of(context).textTheme.titleLarge),
          ...arr(post['responses']).map((r) {
            final response = obj(r);
            return BlinkProListCard(
              icon:Icons.mode_comment_outlined,
              eyebrow:'PUBLIC RESPONSE',
              title:field(response['author'],'name','Blink member'),
              subtitle:field(response,'message'),
              mood:BlinkMood.exchange,
              trailing:owner&&response['acknowledgedAt']==null
                ?IconButton(tooltip:'Acknowledge response',
                  onPressed:()=>_ack(field(response,'id')),
                  icon:const Icon(Icons.done_all,color:BlinkColors.orange))
                :null,
            );
          }),
        ],
      )),
    );
  }
}

class FullExchangeThread extends StatefulWidget {
  const FullExchangeThread({super.key, required this.postId, required this.threadId,
    required this.owner, required this.title});
  final String postId, threadId, title;
  final bool owner;
  @override State<FullExchangeThread> createState() => _FullExchangeThreadState();
}
class _FullExchangeThreadState extends State<FullExchangeThread> {
  final text = TextEditingController();
  List<dynamic> messages = [];
  Map<String, dynamic> offer = {};
  bool loading = true, busy = false;
  String error = '';
  String get base => '/Exchange/' + Uri.encodeComponent(widget.postId) +
    '/chats/' + Uri.encodeComponent(widget.threadId);
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { text.dispose(); super.dispose(); }
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        LiveApi.call('GET', base + '/messages'),
        LiveApi.call('GET', base + '/offer'),
      ]);
      if (mounted) setState(() {
        messages = arr(results[0]);
        offer = obj(results[1]);
        loading = false; error = '';
      });
    } catch (e) { if (mounted) setState(() { loading = false; error = e.toString(); }); }
  }
  Future<void> _send() async {
    if (busy || text.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await LiveApi.call('POST', base + '/messages', {'text': text.text.trim()});
      text.clear(); await _load();
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _propose() async {
    final amount = TextEditingController(text: field(offer, 'amount'));
    String currency = field(offer, 'currency', 'BDT');
    final data = await showDialog<Map<String, String>>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => BlinkFormDialog(
        title: 'Private price offer',
        subtitle: 'Only this conversation can see your price proposal.',
        icon: Icons.local_offer_outlined,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => update(() {}),
            decoration: const InputDecoration(labelText: 'Amount',prefixIcon: Icon(Icons.payments_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: currency, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: _exchangeCurrencies.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) update(() => currency = v); }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: double.tryParse(amount.text.trim()) == null ||
            (double.tryParse(amount.text.trim()) ?? 0) <= 0 ? null : () => Navigator.pop(ctx,
            {'amount': amount.text.trim(), 'currency': currency}),
            child: const Text('Send offer')),
        ],
      )));
    amount.dispose();
    if (data == null) return;
    try {
      await LiveApi.call(offer.isEmpty ? 'POST' : 'PATCH', base + '/offer', data);
      await _load();
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
  }
  Future<void> _decide(String decision) async {
    try {
      await LiveApi.call('POST', base + '/offer/' + decision);
      await _load();
    } catch (e) { if (mounted) liveNotice(context, e.toString()); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: BlinkBrandedTitle(widget.title)),
    body: Column(children: [
      if (offer.isNotEmpty) Card(margin: const EdgeInsets.all(10), child: Padding(
        padding: const EdgeInsets.all(12), child: Column(children: [
          const Text('PRIVATE PRICE OFFER', style: TextStyle(color: BlinkColors.orange,
            fontWeight: FontWeight.w800)),
          Text(field(offer, 'currency') + ' ' + field(offer, 'amount'),
            style: Theme.of(context).textTheme.titleLarge),
          Text('Status: ' + field(offer, 'status')),
          if (widget.owner && field(offer, 'status') == 'PENDING')
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(onPressed: () => _decide('accept'), child: const Text('Accept')),
              TextButton(onPressed: () => _decide('decline'), child: const Text('Decline')),
            ]),
        ]),
      )),
      if (error.isNotEmpty) liveError(error, _load),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load, child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (messages.isEmpty) const ListTile(title: Text('No private messages yet.')),
            ...messages.map((m) => Card(child: ListTile(
              title: Text(field(m['sender'], 'name', 'Member')),
              subtitle: Text(field(m, 'text')),
            ))),
          ],
        ))),
      if (!widget.owner) Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: OutlinedButton.icon(onPressed: _propose,
          icon: const Icon(Icons.payments_outlined),
          label: Text(offer.isEmpty ? 'Make a price offer' : 'Update price offer'))),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Row(children: [
          Expanded(child: TextField(controller: text, minLines: 1, maxLines: 4,
            decoration: const InputDecoration(hintText: 'Negotiation message...'))),
          IconButton(onPressed: busy ? null : _send,
            icon: const Icon(Icons.send, color: BlinkColors.orange)),
        ]))),
    ]),
  );
}
