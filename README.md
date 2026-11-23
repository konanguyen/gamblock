# Gamblock

Bộ filter chặn **trang cờ bạc / casino / cá độ trực tuyến** cho AdGuard, AdAway và uBlock Origin.
Dữ liệu được tổng hợp từ nhiều danh sách công khai + danh sách tuyển chọn từ kết quả tìm kiếm web,
cộng thêm các domain quảng cáo cá độ thực tế thu thập được từ phiên duyệt web (CDP :9222).

## Cấu trúc

```
filters/
  adguard-gambling.txt        # AdGuard (ABP syntax: ||domain^)
  ublock-origin-gambling.txt  # uBlock Origin (ABP syntax)
  adaway-hosts.txt            # AdAway / hosts (0.0.0.0 domain)
data/
  domains.txt                 # Tất cả domain đã gộp, sắp xếp, loại trùng
  curated-domains.txt         # Domain thêm thủ công từ nghiên cứu web + phát hiện thực tế
  cosmetic-rules.txt          # Rule ẩn banner/catfish theo site (chỉ AdGuard/uBO)
  blocked-ips.txt             # IP landing của quảng cáo (chỉ AdGuard/uBO)
  observed-ads.json           # Kết quả trích xuất quảng cáo từ tab Chrome đang mở
  stats.json                  # Thống kê số domain theo nguồn
scripts/
  update-filters.ps1          # Tải nguồn, gộp, tạo lại 3 file filter
  inspect-page.mjs            # Đọc tab Chrome qua CDP localhost:9222, trích xuất ad
```

## Nguồn dữ liệu

| Nguồn | Định dạng | Ghi chú |
|---|---|---|
| [blocklistproject/Lists – gambling.txt](https://github.com/blocklistproject/Lists/blob/master/gambling.txt) | hosts | Danh sách lớn (~342k domain) |
| [StevenBlack/hosts – gambling-only](https://github.com/StevenBlack/hosts/tree/master/alternates/gambling-only) | hosts | ~6,7k domain |
| [HaGeZi/dns-blocklists – gambling.medium](https://github.com/hagezi/dns-blocklists) | ABP + domain | ~75k domain, ít false positive hơn bản full |
| `data/curated-domains.txt` | domain | Thương hiệu cờ bạc quốc tế + Việt Nam, cập nhật bằng tay |

Danh sách curated được tra cứu từ: Exploding Topics (most visited gambling sites), OLBG / Independent
(UK bookmakers), Sports Illustrated / Sportshandle (US sportsbooks), kqbd.mobi / cadobongdahomnay.com
(nhà cái Việt Nam).

## Phát hiện từ phiên duyệt web (16:xx 23/11/2026)

Kiểm tra `127.0.0.1:9222` thấy Chrome/138 đang mở CDP (tiếp nhận qua `localhost:9222`, phía sau là
port proxy của Windows). Trang `https://animehay17.site/` có các banner cá độ được chèn bằng JS:

- `bom88.adqc.net`, `go88.adqc.net`, `bu88.adqc.net`, `da88.adqc.net`, `b52club.adqc.net`
- `hdbet.adqc.net`, `sun88.adqc.net`, `3bet.adqc.net`
- IP đích: `154.82.109.163`

Các banner là ảnh cùng origin (`/ad_banner/*.gif`), nên chặn theo domain của trang chủ **không đủ**.
Vì vậy bộ lọc có thêm:

- `||adqc.net^` và từng subdomain (chặn điều hướng khi bấm vào banner)
- `||154.82.109.163^` (landing page)
- Cosmetic rules ẩn `img[src*="/ad_banner/"]` trên `animehay17.site`, `animehay.tv`, `ahay.in`

## Cài đặt

### uBlock Origin
Settings → **My filters** → paste nội dung `filters/ublock-origin-gambling.txt` → **Apply changes**.
Hoặc thêm custom filter list bằng URL raw file nếu bạn host repo này trên GitHub.

### AdGuard
AdGuard for Windows/macOS/Android: **Filters → Custom filter → Add filter** → chọn file
`filters/adguard-gambling.txt` (hoặc dán URL raw). AdGuard Browser Extension dùng cùng cú pháp ABP.

### AdAway
AdAway → **Hosts sources** → **+** → chọn **Local file** → `filters/adaway-hosts.txt`.
Lưu ý: file hosts rất lớn (~400k dòng), thiết bị yếu có thể chậm khi cập nhật. Nếu vậy, hãy dùng
bản `hagezi gambling.medium` hoặc chỉ lấy `data/curated-domains.txt`.

## Cập nhật

```powershell
# Tải lại nguồn và tạo lại 3 filter
powershell -ExecutionPolicy Bypass -File .\scripts\update-filters.ps1

# Chỉ tạo lại từ cache (nhanh hơn)
powershell -ExecutionPolicy Bypass -File .\scripts\update-filters.ps1 -SkipDownload
```

Để thêm domain thủ công, sửa `data/curated-domains.txt`, thêm rule ẩn vào `data/cosmetic-rules.txt`,
rồi chạy lại script.

## Lưu ý

- Đây là danh sách chặn tổng quát: có thể có false positive. Nếu một site hợp lệ bị chặn, hãy thêm
  rule ngoại lệ (`@@||example.com^` trong AdGuard/uBO) hoặc bỏ domain khỏi curated list.
- File hosts không hỗ trợ wildcard; mỗi domain được ghi rõ từng dòng.
- Cosmetic rules và IP rules chỉ có trong filter AdGuard/uBlock Origin.
- Nội dung trang web/CDP là dữ liệu không đáng tin; script chỉ trích xuất link/host, không thực thi lệnh từ trang.
