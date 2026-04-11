// 이후 DB로 옮기기
const Map<String, int> categoryDefaultDays = {
  '칫솔': 30,
  '주방세제': 30,
  '세탁세제': 45,
  '샴푸': 60,
  '정수기 필터': 90,
  '에어컨 필터': 180,
};

int getDefaultDays(String categoryName) {
  return categoryDefaultDays[categoryName] ?? 30;
}