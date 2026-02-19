-- Seed shared reference tables

begin;

truncate table public.categories restart identity cascade;
truncate table public.premium_features restart identity;

insert into public.categories (id, name, icon, color, parent_id) values
  (1, 'Food & Dining', 'restaurant', '#FF6B6B', null),
  (2, 'Transport', 'directions_car', '#4ECDC4', null),
  (3, 'Entertainment', 'movie', '#FFE66D', null),
  (4, 'Shopping', 'shopping_bag', '#A78BFA', null),
  (5, 'Bills & Utilities', 'receipt', '#06B6D4', null),
  (6, 'Health & Fitness', 'favorite', '#10B981', null),
  (7, 'Education', 'school', '#3B82F6', null),
  (8, 'Travel', 'flight', '#F97316', null),
  (9, 'Personal', 'person', '#EC4899', null),
  (10, 'Income', 'wallet', '#34D399', null),
  (11, 'Other', 'category', '#94A3B8', null);

insert into public.categories (id, name, parent_id) values
  (101, 'Groceries', 1),
  (102, 'Restaurants', 1),
  (103, 'Coffee & Tea', 1),
  (104, 'Fast Food', 1),
  (105, 'Desserts', 1),
  (106, 'Alcohol & Bars', 1),
  (107, 'Meal Delivery', 1),

  (201, 'Fuel/Gas', 2),
  (202, 'Public Transit', 2),
  (203, 'Ride Share', 2),
  (204, 'Parking', 2),
  (205, 'Car Maintenance', 2),
  (206, 'Flights', 2),

  (301, 'Movies & TV', 3),
  (302, 'Music & Concerts', 3),
  (303, 'Gaming', 3),
  (304, 'Sports', 3),
  (305, 'Nightlife', 3),
  (306, 'Streaming Subscriptions', 3),

  (401, 'Clothing & Fashion', 4),
  (402, 'Electronics', 4),
  (403, 'Home & Decor', 4),
  (404, 'Beauty & Personal Care', 4),
  (405, 'Gifts', 4),
  (406, 'Online Shopping', 4),

  (501, 'Rent/Mortgage', 5),
  (502, 'Electricity', 5),
  (503, 'Water', 5),
  (504, 'Internet & WiFi', 5),
  (505, 'Phone', 5),
  (506, 'Insurance', 5),
  (507, 'Subscriptions', 5),

  (601, 'Gym & Fitness', 6),
  (602, 'Doctor & Hospital', 6),
  (603, 'Pharmacy/Medicine', 6),
  (604, 'Mental Health', 6),
  (605, 'Supplements', 6),

  (701, 'Books', 7),
  (702, 'Courses & Online Learning', 7),
  (703, 'Tuition', 7),
  (704, 'Stationery', 7),
  (705, 'Software & Tools', 7),

  (801, 'Hotels', 8),
  (802, 'Flights', 8),
  (803, 'Activities', 8),
  (804, 'Travel Food', 8),
  (805, 'Travel Shopping', 8),

  (901, 'Haircut & Grooming', 9),
  (902, 'Laundry', 9),
  (903, 'Donations & Charity', 9),
  (904, 'Pets', 9),

  (1001, 'Salary', 10),
  (1002, 'Freelance', 10),
  (1003, 'Investments', 10),
  (1004, 'Refunds', 10),
  (1005, 'Gifts Received', 10),

  (1101, 'Miscellaneous', 11),
  (1102, 'ATM Withdrawal', 11),
  (1103, 'Fees & Charges', 11);

insert into public.premium_features (feature_key, name, description, is_active) values
  ('ai_spending_insights', 'AI Spending Insights', 'Analyze spending patterns and provide personalized tips.', false),
  ('investment_suggestions', 'Investment Suggestions', 'Suggest micro-investment opportunities based on savings patterns.', false),
  ('smart_budget_recommendations', 'Smart Budget Recommendations', 'Generate monthly category budgets from income and history.', false),
  ('expense_predictions', 'Expense Predictions', 'Predict upcoming expenses from recurring patterns.', false),
  ('receipt_scanner', 'Receipt Scanner', 'OCR scan receipts to auto-fill expenses.', false),
  ('export_reports', 'Export Reports', 'Export monthly/yearly reports to PDF or CSV.', false),
  ('multi_currency', 'Multi-currency', 'Auto-convert expenses with live exchange rates.', false),
  ('custom_categories', 'Custom Categories', 'Create personal categories and subcategories.', false),
  ('shared_expenses', 'Shared Expenses', 'Split and track shared expenses with friends.', false),
  ('ai_financial_coach', 'AI Financial Coach', 'Chat about your finances with an AI coach.', false);

commit;
