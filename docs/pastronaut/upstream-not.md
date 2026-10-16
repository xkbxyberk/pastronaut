# Upstream'e not (taslak, gönderilmedi)

**Nereye:** p0deje/Maccy → Discussions'ta yeni bir tartışma. #182 (cloud sync) ve #762 (iOS app) bağlantılı.
Konu iki issue'yu da kapsadığı ve bir soru içerdiği için tartışma daha uygun.
**Bağlam:**
- Proje sahibi #182'de (2020) "kendim yapmayacağım ama eşitleme ekleyen PR'ları birleştiririm" demiş.
- #762'de (2024) "iOS uygulaması sıfırdan yazılmalı, buna yatırım yapmayı düşünmüyorum" demiş.
- Aralık 2025'te ana projede hareketsiz bir `claude/maccy-ios-port-plan-…` dalı açılmış.

---

**Title:** Heads-up: a free iOS companion with a history keyboard, built on a Maccy fork

Hi @p0deje, and thank you for Maccy.

I'm starting a fork called **Pastronaut** (github.com/xkbxyberk/pastronaut). The goal is to bring Maccy's history to
the iPhone, which is what #182 and #762 ask for:

- **iCloud sync** through the user's private CloudKit database. Clip contents go in encrypted fields, and only items
  that already passed Maccy's ignore rules are synced.
- A **free iOS app with a custom keyboard** that shows the shared history and types an item with one tap. Copies made
  on the iPhone are captured too: when the app or keyboard opens, through a Shortcuts action, and via Universal Clipboard.

To be clear about the fork:
- It will be **free**, with no in-app purchases.
- It uses a different name and icon with no Maccy branding, and says plainly that it is not affiliated with Maccy.
- The MIT notice is kept in the repo and shown in the app.
- Mac changes stay small and isolated (a separate `Sync/` folder plus a few hooks) so I can keep merging upstream.

I noticed the `claude/maccy-ios-port-plan-…` branch from December. Two questions before I go further:

1. **Do you plan to ship an official iOS companion?** If so, I'd rather contribute to it than compete with it.
2. **Would you want the sync layer upstream as a PR for #182?** One caveat: CloudKit containers are tied to a
   developer team. An iOS app published from my account can't sync with the official Maccy build. If you'd prefer
   that everything lives under Maccy's team, I'm happy to discuss how to do that.

Either way, thanks again. If you'd rather I handle anything differently (naming, attribution), please tell me.

— @xkbxyberk

---

## Türkçe özet (kullanıcı için)
Not, çatalın amacını ve sınırlarını açıklıyor: ücretsiz, farklı ad ve ikon, MIT bildirimi korunuyor, Mac değişiklikleri küçük
tutuluyor. Ardından iki şey soruyor:
1. Proje sahibi resmi bir iOS uygulaması planlıyor mu? Planlıyorsa ona katkı vermeyi teklif ediyor.
2. Eşitleme katmanını ana projeye PR olarak ister mi? iCloud kapsayıcısının ekibe bağlı olduğunu açıkça belirtiyor.
