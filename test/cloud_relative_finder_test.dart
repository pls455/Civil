  });

  test('unique relationship matching continues past the first page', () async {
    final root = person(
      id: 'root',
      name: 'علي',
      father: 'محمد',
      grandfather: 'حسن',
      family: 'المصري',
    );

    final decoys = List.generate(
      100,
      (index) => person(
        id: 'decoy-$index',
        name: 'محمدية$index',
        father: 'حسن',
        grandfather: 'سالم',
        family: 'المصري',
      ),
    );

    final father = person(
      id: 'father',
      name: 'محمد',
      father: 'حسن',
      grandfather: 'حسن',
      family: 'المصري',
    );

    final finder = CloudRelativeFinder(
      _FakeCloudSearchEngine([
        ...decoys,
        father,
        root,
      ]),
    );

    final relatives = await finder.findForPerson(root);

    expect(
      relatives.any(
        (item) =>
            item.type == CloudRelativeType.father &&
            item.person.id == 'father',
      ),
      isTrue,
    );
  });
}