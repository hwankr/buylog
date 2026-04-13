// 이후 DB로 옮기기
const Map<String, int> categoryDefaultDays = {
  '욕실/위생': 30, // 칫솔 등
  '주방/세제': 30, // 주방세제 등
  '세탁/청소': 45, // 세탁세제 등
  '헤어/바디': 60, // 샴푸 등
  '가전/필터': 90, // 정수기/에어컨 필터 (더 긴 쪽으로 맞추거나 평균값)
};

int getDefaultDays(String categoryName) {
  return categoryDefaultDays[categoryName] ?? 30;
}
