// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.ledger.fidl/ledger.fidl.dart' as ledger;
import 'package:lib.logging/logging.dart';
import 'package:lib.modular/ledger.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.contacts.services/contacts_content_provider.fidl.dart';

import '../store/contacts_store.dart';
import 'contacts_watcher.dart';

/// Initial stub implementation
class ContactsContentProviderImpl extends ContactsContentProvider {
  final ContactsStore<Contact> _contactsStore = new ContactsStore<Contact>();
  final List<ContactsContentProviderBinding> _bindings =
      <ContactsContentProviderBinding>[];

  /// [ComponentContext] used for interfacing with Ledger
  final ComponentContext componentContext;

  /// [Ledger] instance
  ledger.LedgerProxy _ledger;

  /// Ledger [Page] instance containing contacts
  ledger.PageProxy _page;

  /// Watcher to keep track of updates to the Ledger [Page]
  ContactsWatcher _contactsWatcher;

  /// Constructor
  ContactsContentProviderImpl({@required this.componentContext})
      : assert(componentContext != null);

  /// Runs necessary methods to initialize the contacts content provider
  Future<Null> initialize() async {
    // Connect to ledger
    try {
      await _initializeLedgerConnection();
    } on Exception catch (e, stackTrace) {
      log.severe('Failed to initialize', e, stackTrace);
      return;
    }

    // Grab user's contacts
    bool errorReadingLedgerContacts = false;
    List<Contact> ledgerContacts;
    try {
      ledgerContacts = await _getLedgerContacts(_page);
    } on Exception catch (e, stackTrace) {
      errorReadingLedgerContacts = true;
      log.severe('Failed to read ledger contacts', e, stackTrace);
    }
    if (!errorReadingLedgerContacts && ledgerContacts.isNotEmpty) {
      _addContactsToStore(ledgerContacts);
      log.fine('Initialized contacts store from ledger');
    } else {
      // Grab contacts from the contacts providers and save to ledger, rather
      // than adding them to the store immediately we will wait until the
      // changes propagate back from Ledger via the page watcher to add them
      // the store.
      // TODO(meiyili) handle errors gracefully SO-810, i.e. couldn't save
      // TODO(meiyili) replace with a call to the necessary service agents and
      // ledger and create a fixture with the stub contact generation code
      List<Contact> contacts = _getStubContactList();
      await _saveContactsToLedger(contacts);
      log.fine('Ledger empty, initialized contacts store from service');
    }
    log.fine('Initialization completed');
  }

  @override
  Future<Null> getContactList(String prefix,
      void callback(Status status, List<Contact> contacts)) async {
    List<Contact> contactsList;
    if (prefix == null || prefix == '') {
      contactsList = _contactsStore.getAllContacts();
    } else {
      Map<String, Set<Contact>> contacts = _contactsStore.search(prefix);

      // Merge into a set first to avoid duplicates
      contactsList =
          contacts.values.expand((Set<Contact> s) => s).toSet().toList();
    }
    callback(Status.ok, contactsList);
    return;
  }

  @override
  Future<Null> getContact(
      String id, void callback(Status status, Contact contact)) async {
    callback(Status.ok, _contactsStore.getContact(id));
    return;
  }

  /// Add request to the list of binding objects.
  void addBinding(InterfaceRequest<ContactsContentProvider> request) {
    _bindings.add(new ContactsContentProviderBinding()..bind(this, request));
  }

  /// Close all the bindings.
  void close() {
    for (ContactsContentProviderBinding binding in _bindings) {
      binding.close();
    }
    _bindings.clear();

    // Close Ledger bindings
    _contactsWatcher?.close();
    _page?.ctrl?.close();
    _ledger?.ctrl?.close();
  }

  void _addContactsToStore(List<Contact> contacts) {
    for (Contact contact in contacts) {
      List<String> searchableValues = <String>[
        contact.displayName.trim().toLowerCase(),
        contact.familyName.trim().toLowerCase(),
        contact.emails[0].value.trim().toLowerCase(),
      ];
      _contactsStore.addContact(
        contact.googleContactId,
        contact.displayName,
        searchableValues,
        contact,
        updateIfExists: true,
      );
    }
  }

  /// Temporary for stub implementations
  /// TODO(meiyili) remove when implementing the actual methods
  Contact _createStubContact(String id, String givenName, String familyName) {
    return new Contact()
      ..googleContactId = id
      ..displayName = '$givenName $familyName'
      ..givenName = givenName
      ..middleName = givenName.substring(0, 1)
      ..familyName = familyName
      ..emails = <EmailAddress>[
        new EmailAddress()
          ..label = 'primary'
          ..value = '$familyName$givenName@example.com'.toLowerCase()
      ]
      ..phoneNumbers = <PhoneNumber>[
        new PhoneNumber()
          ..label = 'mobile'
          ..value = '12345678910'
      ]
      ..photoUrl = '';
  }

  List<Contact> _getStubContactList() {
    return <Contact>[
      _createStubContact('1', 'Ahonui', 'Armadillo'),
      _createStubContact('2', 'Badia', 'Blue-Whale'),
      _createStubContact('3', 'Candida', 'Capybara'),
      _createStubContact('4', 'Daniel', 'Dewey'),
      _createStubContact('5', 'Ada', 'Lovelace'),
      _createStubContact('6', 'Alan', 'Turing'),
      _createStubContact('7', 'Barbara', 'McClintock'),
      _createStubContact('8', 'Benjamin', 'Banneker'),
      _createStubContact('9', 'Clara', 'Schumann'),
      _createStubContact('10', 'Claude', 'Debussy'),
      _createStubContact('11', 'Daphne', 'du Maurier'),
      _createStubContact('12', 'Dmitri', 'Mendeleev'),
    ];
  }

  /// Initialize connection to ledger and get the page of contacts data
  Future<Null> _initializeLedgerConnection() async {
    // Connect to ledger
    _ledger?.ctrl?.close();
    _ledger = new ledger.LedgerProxy();
    Completer<ledger.Status> statusCompleter = new Completer<ledger.Status>();
    componentContext.getLedger(
      _ledger.ctrl.request(),
      statusCompleter.complete,
    );
    ledger.Status status = await statusCompleter.future;
    _handleLedgerResponseStatus(
      status: status,
      ledgerCall: 'componentContext.getLedger()',
    );

    // Grab the page of contacts
    _page?.ctrl?.close();
    _page = new ledger.PageProxy();
    statusCompleter = new Completer<ledger.Status>();
    _ledger.getRootPage(
      _page.ctrl.request(),
      statusCompleter.complete,
    );
    ledger.Status pageStatus = await statusCompleter.future;
    _handleLedgerResponseStatus(
      status: pageStatus,
      ledgerCall: 'ledger.getRootPage()',
    );
  }

  Future<List<Contact>> _getLedgerContacts(ledger.PageProxy page) async {
    if (page == null) {
      // TODO(meiyili): handle ledger errors gracefully SO-810
      log.warning('getLedgerContacts was called on a null page');
      return <Contact>[];
    }
    ledger.PageSnapshotProxy snapshot = new ledger.PageSnapshotProxy();

    // Create the watcher that will listen to changes on the page
    _contactsWatcher = new ContactsWatcher(
      initialSnapshot: snapshot,
      processEntriesCallback: (List<ledger.Entry> entries) {
        _addContactsToStore(_getContactsFromEntries(entries));
      },
    );

    Completer<ledger.Status> statusCompleter = new Completer<ledger.Status>();
    page.getSnapshot(
      snapshot.ctrl.request(),
      null,
      _contactsWatcher.pageWatcherHandle,
      statusCompleter.complete,
    );
    ledger.Status status = await statusCompleter.future;
    _handleLedgerResponseStatus(
      status: status,
      ledgerCall: 'page.getSnapshot()',
    );

    return _getContactsFromEntries(await getFullEntries(snapshot));
  }

  List<Contact> _getContactsFromEntries(List<ledger.Entry> entries) {
    List<Contact> contacts = <Contact>[];
    if (entries.isNotEmpty) {
      contacts = entries.map(_getContactFromEntry);
    }
    return contacts;
  }

  Contact _getContactFromEntry(ledger.Entry entry) {
    String contactId = UTF8.decode(entry.key);
    Map<String, dynamic> decodedValue = decodeLedgerValue(entry.value);

    List<EmailAddress> emails = <EmailAddress>[];
    for (Map<String, String> email in decodedValue['emails']) {
      emails.add(new EmailAddress()
        ..label = email['label']
        ..value = email['value']);
    }

    List<PhoneNumber> phoneNumbers = <PhoneNumber>[];
    for (Map<String, String> number in decodedValue['phoneNumbers']) {
      phoneNumbers.add(new PhoneNumber()
        ..label = number['label']
        ..value = number['value']);
    }
    return new Contact()
      ..googleContactId = contactId
      ..displayName = decodedValue['displayName']
      ..givenName = decodedValue['givenName']
      ..middleName = decodedValue['middleName']
      ..familyName = decodedValue['familyName']
      ..photoUrl = decodedValue['photoUrl']
      ..emails = emails
      ..phoneNumbers = phoneNumbers;
  }

  Future<Null> _saveContactsToLedger(List<Contact> contacts) async {
    if (_page == null) {
      // TODO(meiyili): handle ledger errors gracefully SO-810
      log.warning('saveContactsToLedger was called on a null page');
      return;
    }
    for (Contact contact in contacts) {
      List<int> contactId = UTF8.encode(contact.googleContactId);
      List<int> ledgerValue = encodeLedgerValue(contact);
      _page.put(
        contactId,
        ledgerValue,
        (ledger.Status status) {
          // TODO(meiyili): retry put calls that returned with an error SO-810
          if (status != ledger.Status.ok) {
            log.severe('page.put returned an error');
          } else {
            log.fine('page.put succeeded');
          }
        },
      );
    }
  }

  /// Handles response status, throws an exception if the status is not ok
  void _handleLedgerResponseStatus({ledger.Status status, String ledgerCall}) {
    // TODO(meiyili): handle ledger errors and try to reconnect if there were
    // status errors SO-810
    if (status != ledger.Status.ok) {
      log.severe('Ledger error: $ledgerCall');
      throw new Exception(
        'Contacts Content Provider Ledger call error: '
            'status = $status, message = "$ledgerCall returned an error"',
      );
    } else {
      log.fine('$ledgerCall succeeded');
    }
  }
}
