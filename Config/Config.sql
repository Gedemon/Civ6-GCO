
DELETE from Rulesets WHERE RulesetType <> 'RULESET_STANDARD';
DELETE from GameModeItems;
DELETE from Parameters WHERE ParameterId LIKE '%GameMode_%';