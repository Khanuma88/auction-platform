-- Seed data: categories. Prohibited ones are what the AI screening checks against.
INSERT INTO category (name, description, prohibited) VALUES
    ('Electronics',       'Phones, computers, audio and photo equipment', FALSE),
    ('Art',               'Paintings, prints, sculptures',                FALSE),
    ('Collectibles',      'Coins, stamps, trading cards, memorabilia',    FALSE),
    ('Books',             'New, used and antique books',                  FALSE),
    ('Fashion',           'Clothing, shoes, accessories',                 FALSE),
    ('Home and garden',   'Furniture, tools, decoration',                 FALSE),
    ('Weapons',           'Firearms, ammunition, bladed weapons',         TRUE),
    ('Live animals',      'Pets and livestock',                           TRUE),
    ('Counterfeit goods', 'Replicas sold as originals',                   TRUE),
    ('Medicines',         'Prescription drugs and medical substances',    TRUE);
