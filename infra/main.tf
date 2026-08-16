resource "terraform_data" "lock_check" {
  input = "3"   # 값을 바꿀 때마다 변경이 생기는 걸 이용해 lock 실습 전용으로 둔다.
}