alter table `deliverables` add column `position` int(11) after `description`;

update `deliverables` set `position` = 1;

alter table `issue_deliverables` add column `position` int(11) after `deliverable_id`;

update `issue_deliverables` set `position` = 1;
