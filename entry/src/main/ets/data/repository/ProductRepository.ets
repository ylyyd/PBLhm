import { Product, ProductSpec, SKU } from '../model/ProductModel'
import { HttpClient } from '../HttpClient'
import { Logger } from '../../common/Logger'

export class CategoryNode {
  name: string = ''
  children: string[] = []
}

export class SearchResult {
  items: Product[] = []
  total: number = 0
}

export class ProductRepository {
  private cachedProducts: Product[] = []
  private cachedCategoryTree: CategoryNode[] = []
  private lastProductLoadTime: number = 0
  private lastCategoryLoadTime: number = 0
  private loadPromise: Promise<void> | null = null
  private readonly PRODUCT_TTL: number = 5 * 60 * 1000 // 5 minutes
  private readonly CATEGORY_TTL: number = 30 * 60 * 1000 // 30 minutes

  async load(): Promise<void> {
    const now = Date.now()
    if (this.cachedProducts.length > 0 && now - this.lastProductLoadTime < this.PRODUCT_TTL &&
        this.cachedCategoryTree.length > 0 && now - this.lastCategoryLoadTime < this.CATEGORY_TTL) {
      return
    }
    if (this.loadPromise) return this.loadPromise
    this.loadPromise = this.doLoad()
    await this.loadPromise
    this.loadPromise = null
  }

  async refresh(): Promise<void> {
    this.lastProductLoadTime = 0
    this.lastCategoryLoadTime = 0
    await this.load()
  }

  private async doLoad(): Promise<void> {
    try {
      const now = Date.now()
      // Fetch products if TTL expired or never loaded
      if (this.cachedProducts.length === 0 || now - this.lastProductLoadTime >= this.PRODUCT_TTL) {
        let productsData: Object | null = await HttpClient.getSilent('/products?pageSize=200')
        let resp = productsData as Record<string, Object> | null
        if (resp) {
          let raw = resp.items as Record<string, Object>[]
          this.cachedProducts = (raw || []).map(item => {
            let p = new Product()
            p.id = item.id as number || 0
            p.name = item.name as string || ''
            p.price = item.price as number || 0
            p.image = item.image as string || ''
            p.images = item.images as string[] || []
            p.description = item.description as string || ''
            p.detailHtml = (item.detail_html as string) || ''
            p.category = item.category as string || ''
            p.specs = item.specs as ProductSpec[] || []
            p.skus = item.skus as SKU[] || []
            p.shopId = (item.shop_id as number) || 0
            p.shopName = (item.shop_name as string) || ''
            p.salesCount = (item.sales_count as number) || 0
            p.rating = (item.rating as number) || 0
            p.reviewCount = (item.reviewCount as number) || 0
            p.stock = (item.stock as number) || 0
            return p
          })
          this.lastProductLoadTime = now
        }
      }
      // Fetch categories if TTL expired or never loaded
      if (this.cachedCategoryTree.length === 0 || now - this.lastCategoryLoadTime >= this.CATEGORY_TTL) {
        let catsData: Object | null = await HttpClient.getSilent('/products/categories')
        let catsResp = catsData as Record<string, Object> | null
        if (catsResp) {
          let rawArr = catsResp.categories as Record<string, Object>[] || []
          this.cachedCategoryTree = rawArr.map(item => {
            let node = new CategoryNode()
            node.name = String(item.name || '')
            let rawChildren = item.children as Record<string, Object>[]
            node.children = (rawChildren || []).map(c => String((c as Record<string, Object>).name !== undefined ? (c as Record<string, Object>).name : c))
            return node
          })
          this.lastCategoryLoadTime = now
        }
      }
    } catch (err) {
      Logger.error('ProductRepository.doLoad failed: {0}', err instanceof Error ? err.message : '')
    }
    // 如果 API 请求后数据仍为空（服务器不可用/出错），加载 fallback
    if (this.cachedProducts.length === 0 || this.cachedCategoryTree.length === 0) {
      this.loadFallbackData()
    }
  }

  private loadFallbackData(): void {
    let makeProduct = (id: number, name: string, price: number, image: string, category: string, description: string, specArr?: Object[], skuArr?: Object[], stock: number = 999): Product => {
      let p = new Product()
      p.id = id; p.name = name; p.price = price; p.image = image
      p.images = image ? [image] : []; p.category = category; p.description = description
      p.stock = stock
      if (specArr) { p.specs = specArr as ProductSpec[] }
      if (skuArr) { p.skus = skuArr as SKU[] }
      return p
    }
    let p1 = makeProduct(1, '华为Mate60 Pro', 6999, 'mate60pro_1.png', '手机>华为', '华为旗舰手机，搭载自研麒麟9000S芯片，支持卫星通话')
    p1.images = ['mate60pro_1.png', 'mate60pro_2.png', 'mate60pro_3.png', 'mate60pro_4.png']
    let p2 = makeProduct(2, 'Apple iPhone 15', 7999, 'iphone15_1.png', '手机>iPhone', 'A16仿生芯片，4800万像素主摄，灵动岛交互')
    p2.images = ['iphone15_1.png', 'iphone15_2.png', 'iphone15_3.png', 'iphone15_4.png']
    let p3 = makeProduct(3, '小米14 Ultra', 5999, 'mi14ultra_1.png', '手机>小米', '骁龙8Gen3处理器，徕卡光学镜头，2K AMOLED屏幕')
    p3.images = ['mi14ultra_1.png', 'mi14ultra_2.png', 'mi14ultra_3.png', 'mi14ultra_4.png']
    let p4 = makeProduct(4, 'Redmi K70', 2499, 'redmik70_1.png', '手机>小米', '骁龙8Gen2芯片，2K直屏，120W快充')
    p4.images = ['redmik70_1.png', 'redmik70_2.png', 'redmik70_3.png']
    let p5 = makeProduct(5, '联想小新Pro 16', 5999, 'lenovo_xiaoxin_1.png', '电脑>联想', '高性能轻薄本，16英寸2.5K大屏')
    p5.images = ['lenovo_xiaoxin_1.png', 'lenovo_xiaoxin_2.png', 'lenovo_xiaoxin_3.png']
    let p6 = makeProduct(6, 'MacBook Air M3', 8999, 'macbookair_1.png', '电脑>苹果', 'M3芯片，13.6英寸Liquid Retina显示屏')
    p6.images = ['macbookair_1.png', 'macbookair_2.png', 'macbookair_3.png', 'macbookair_4.png']
    let p7 = makeProduct(7, '华为MateBook X Pro', 9999, 'matebookx_1.png', '电脑>华为', '3.1K OLED原色屏，超级终端')
    p7.images = ['matebookx_1.png', 'matebookx_2.png', 'matebookx_3.png', 'matebookx_4.png']
    let p8 = makeProduct(8, '华硕灵耀14', 4999, 'p_华硕灵耀14_1781524671252_1.png', '电脑>华硕', '14英寸2.8K OLED屏，轻约1.3kg')
    p8.images = ['p_华硕灵耀14_1781524671252_1.png','p_华硕灵耀14_1781524671252_2.png']
    let p9 = makeProduct(9, 'AirPods Pro 2', 1899, 'airpodspro2_1.png', '配件>耳机', '主动降噪无线耳机，自适应音频')
    p9.images = ['airpodspro2_1.png', 'airpodspro2_2.png', 'airpodspro2_3.png', 'airpodspro2_4.png']
    let p10 = makeProduct(10, '倍思65W充电器', 129, 'p_倍思65W充电器_1781524670512_1.png', '配件>充电器', '氮化镓65W快充，三口输出')
    p10.images = ['p_倍思65W充电器_1781524670512_1.png','p_倍思65W充电器_1781524670512_2.png']
    let p11 = makeProduct(11, '绿联Type-C数据线', 29, 'p_绿联TypeC数据线_1781524670548_1.png', '配件>数据线', '5A大电流快充数据线')
    p11.images = ['p_绿联TypeC数据线_1781524670548_1.png','p_绿联TypeC数据线_1781524670548_2.png']
    let p12 = makeProduct(12, '小米移动电源3', 199, 'p_小米移动电源3_1781524670576_1.png', '配件>充电宝', '20000mAh大容量，双向快充')
    p12.images = ['p_小米移动电源3_1781524670576_1.png','p_小米移动电源3_1781524670576_2.png']
    let p13 = makeProduct(13, '小米电视S75', 3999, 'mitvs75_1.png', '家电>电视', '75英寸4K超清智能电视，120Hz高刷新率')
    p13.images = ['mitvs75_1.png', 'mitvs75_2.png', 'mitvs75_3.png', 'mitvs75_4.png']
    let p14 = makeProduct(14, '格力空调KFR-35GW', 3299, 'gree_ac_1.png', '家电>空调', '1.5匹新一级能效，变频冷暖')
    p14.images = ['gree_ac_1.png', 'gree_ac_2.png', 'gree_ac_3.png']
    let p15 = makeProduct(15, '海尔滚筒洗衣机', 2999, 'p_海尔滚筒洗衣机_1781524670404_1.png', '家电>洗衣机', '10公斤大容量，变频静音')
    p15.images = ['p_海尔滚筒洗衣机_1781524670404_1.png','p_海尔滚筒洗衣机_1781524670404_2.png']
    let p16 = makeProduct(16, '美的双开门冰箱', 3999, 'p_美的双开门冰箱_1781524670461_1.png', '家电>冰箱', '470升双开门，风冷无霜')
    p16.images = ['p_美的双开门冰箱_1781524670461_1.png','p_美的双开门冰箱_1781524670461_2.png']
    let p17 = makeProduct(17, '小米智能音箱', 299, 'p_小米智能音箱_1781524670601_1.png', '生活>智能设备', '小爱同学语音助手，智能家居控制中心')
    p17.images = ['p_小米智能音箱_1781524670601_1.png','p_小米智能音箱_1781524670601_2.png']
    let p18 = makeProduct(18, '得力无线打印机', 899, 'p_得力无线打印机_1781524671392_1.png', '生活>办公设备', '彩色喷墨，无线连接')
    p18.images = ['p_得力无线打印机_1781524671392_1.png','p_得力无线打印机_1781524671392_2.png']
    let p19 = makeProduct(19, '飞利浦电动牙刷', 399, 'p_飞利浦电动牙刷_1781524670624_1.png', '生活>个护健康', '声波震动技术，智能压力感应')
    p19.images = ['p_飞利浦电动牙刷_1781524670624_1.png','p_飞利浦电动牙刷_1781524670624_2.png']
    let p20 = makeProduct(20, '米家空气净化器', 1499, '', '生活>智能设备', 'CADR值500m³/h，高效除甲醛')
    let p21 = makeProduct(21, '海信激光电视100寸', 19999, '', '家电>电视', '100英寸4K激光电视，影院级体验')
    let p22 = makeProduct(22, '科沃斯扫地机器人', 2499, 'p_科沃斯扫地机器人_1781524670484_1.png', '家电>扫地机器人', '智能导航扫拖一体，自动集尘')
    p22.images = ['p_科沃斯扫地机器人_1781524670484_1.png','p_科沃斯扫地机器人_1781524670484_2.png']
    let p23 = makeProduct(23, '海尔热水器60L', 1599, 'p_海尔热水器60L_1781524671361_1.png', '家电>热水器', '60升储水式电热水器，一级能效')
    p23.images = ['p_海尔热水器60L_1781524671361_1.png','p_海尔热水器60L_1781524671361_2.png']
    let p24 = makeProduct(24, '无印良品纯棉T恤', 129, 'p_无印良品纯棉T恤_1781524670650_1.png', '服装>男装', '纯棉圆领短袖T恤，舒适透气')
    p24.images = ['p_无印良品纯棉T恤_1781524670650_1.png','p_无印良品纯棉T恤_1781524670650_2.png']
    let p25 = makeProduct(25, '江南布衣连衣裙', 399, 'p_江南布衣连衣裙_1781524671465_1.png', '服装>女装', '优雅碎花连衣裙，夏日清爽')
    p25.images = ['p_江南布衣连衣裙_1781524671465_1.png','p_江南布衣连衣裙_1781524671465_2.png']
    let p26 = makeProduct(26, '耐克Air Force 1', 799, 'p_耐克AirForce1_1781524671487_1.png', '服装>运动鞋', '经典空军一号，百搭小白鞋')
    p26.images = ['p_耐克AirForce1_1781524671487_1.png','p_耐克AirForce1_1781524671487_2.png']
    let p27 = makeProduct(27, 'COACH手提包', 2599, 'p_COACH手提包_1781524671536_1.png', '服装>包包', '经典老花图案，轻奢时尚')
    p27.images = ['p_COACH手提包_1781524671536_1.png','p_COACH手提包_1781524671536_2.png']
    let p28 = makeProduct(28, '兰蔻小黑瓶精华', 1080, 'p_兰蔻小黑瓶精华_1781524671561_1.png', '美妆>护肤', '第二代小黑瓶肌底精华液，修护肌肤')
    p28.images = ['p_兰蔻小黑瓶精华_1781524671561_1.png','p_兰蔻小黑瓶精华_1781524671561_2.png']
    let p29 = makeProduct(29, '迪奥999口红', 350, 'p_迪奥999口红_1781524670669_1.png', '美妆>彩妆', '传奇红唇，哑光质感')
    p29.images = ['p_迪奥999口红_1781524670669_1.png','p_迪奥999口红_1781524670669_2.png']
    let p30 = makeProduct(30, '爱马仕大地香水', 1280, 'p_爱马仕大地香水_1781524671581_1.png', '美妆>香水', '木质调男士淡香水，经典沉稳')
    p30.images = ['p_爱马仕大地香水_1781524671581_1.png','p_爱马仕大地香水_1781524671581_2.png']
    // ── 食品（无合适回退图，留空显示占位） ──
    let p31 = makeProduct(31, '良品铺子零食大礼包', 99, 'p_良品铺子零食大礼包_1781524670692_1.png', '食品>零食', '坚果果脯零食大礼包，内含20种美味')
    p31.images = ['p_良品铺子零食大礼包_1781524670692_1.png','p_良品铺子零食大礼包_1781524670692_2.png']
    let p32 = makeProduct(32, '西湖龙井明前茶', 298, 'p_西湖龙井明前茶_1781524670720_1.png', '食品>茶饮', '正宗西湖龙井，明前特级绿茶')
    p32.images = ['p_西湖龙井明前茶_1781524670720_1.png','p_西湖龙井明前茶_1781524670720_2.png']
    let p33 = makeProduct(33, '五常稻花香大米', 69, 'p_五常稻花香大米_1781524670745_1.png', '食品>粮油调味', '东北五常稻花香，优质一等大米5kg')
    p33.images = ['p_五常稻花香大米_1781524670745_1.png','p_五常稻花香大米_1781524670745_2.png']
    // ── 图书 ──
    let p34 = makeProduct(34, '三体全集', 128, 'p_三体全集_1781524670763_1.png', '图书>文学', '刘慈欣科幻巨著，雨果奖获奖作品')
    p34.images = ['p_三体全集_1781524670763_1.png','p_三体全集_1781524670763_2.png']
    let p35 = makeProduct(35, 'Python编程 从入门到实践', 89, 'p_Python编程从入门到实践_1781524670782_1.png', '图书>科技', '零基础学Python，畅销编程入门书')
    p35.images = ['p_Python编程从入门到实践_1781524670782_1.png','p_Python编程从入门到实践_1781524670782_2.png']
    let p36 = makeProduct(36, '小王子（精装插图版）', 39, 'p_小王子精装插图版_1781524670805_1.png', '图书>童书', '圣埃克苏佩里经典童话，全彩插图')
    p36.images = ['p_小王子精装插图版_1781524670805_1.png','p_小王子精装插图版_1781524670805_2.png']
    // ── 运动 ──
    let p37 = makeProduct(37, '李宁飞电4.0跑鞋', 699, 'p_李宁飞电40跑鞋_1781524670824_1.png', '运动>运动鞋服', '专业马拉松竞速跑鞋，䨻科技回弹')
    p37.images = ['p_李宁飞电40跑鞋_1781524670824_1.png','p_李宁飞电40跑鞋_1781524670824_2.png']
    let p38 = makeProduct(38, 'Keep专业瑜伽垫', 129, 'p_Keep专业瑜伽垫_1781524670841_1.png', '运动>瑜伽', 'NBR材质环保无味，加厚防滑健身垫')
    p38.images = ['p_Keep专业瑜伽垫_1781524670841_1.png','p_Keep专业瑜伽垫_1781524670841_2.png']
    let p39 = makeProduct(39, '牧高笛户外帐篷', 599, 'p_牧高笛户外帐篷_1781524670865_1.png', '运动>户外装备', '双人双层防雨帐篷，全自动速开')
    p39.images = ['p_牧高笛户外帐篷_1781524670865_1.png','p_牧高笛户外帐篷_1781524670865_2.png']
    // ── 母婴 ──
    let p40 = makeProduct(40, '美赞臣铂睿3段奶粉', 268, 'p_美赞臣铂睿3段奶粉_1781524670883_1.png', '母婴>奶粉', '荷兰进口，1-3岁幼儿配方奶粉900g')
    p40.images = ['p_美赞臣铂睿3段奶粉_1781524670883_1.png','p_美赞臣铂睿3段奶粉_1781524670883_2.png']
    let p41 = makeProduct(41, '帮宝适一级帮纸尿裤', 189, 'p_帮宝适一级帮纸尿裤_1781524670901_1.png', '母婴>纸尿裤', '日本进口，透气瞬吸L码64片')
    p41.images = ['p_帮宝适一级帮纸尿裤_1781524670901_1.png','p_帮宝适一级帮纸尿裤_1781524670901_2.png']
    let p42 = makeProduct(42, '乐高经典创意积木', 299, 'p_乐高经典创意积木_1781524670919_1.png', '母婴>玩具', '经典大盒装，1066颗粒，激发创造力')
    p42.images = ['p_乐高经典创意积木_1781524670919_1.png','p_乐高经典创意积木_1781524670919_2.png']
    // ── 宠物 ──
    let p43 = makeProduct(43, '皇家狗粮小型成犬粮', 178, 'p_皇家狗粮小型成犬粮_1781524670941_1.png', '宠物>狗粮', '法国品牌，小型犬专用粮4kg')
    p43.images = ['p_皇家狗粮小型成犬粮_1781524670941_1.png','p_皇家狗粮小型成犬粮_1781524670941_2.png']
    let p44 = makeProduct(44, '伟嘉猫粮海洋鱼味', 89, 'p_伟嘉猫粮海洋鱼味_1781524670959_1.png', '宠物>猫粮', '成猫主粮，海洋鱼味拼盘2.5kg')
    p44.images = ['p_伟嘉猫粮海洋鱼味_1781524670959_1.png','p_伟嘉猫粮海洋鱼味_1781524670959_2.png']
    // ── 家装 ──
    let p45 = makeProduct(45, '北欧LED台灯', 159, 'p_北欧LED台灯_1781524670980_1.png', '家装>灯具', '护眼台灯，三档色温可调，触摸开关')
    p45.images = ['p_北欧LED台灯_1781524670980_1.png','p_北欧LED台灯_1781524670980_2.png']
    let p46 = makeProduct(46, '60支纯棉四件套', 329, 'p_60支纯棉四件套_1781524671003_1.png', '家装>家纺', '高支高密纯棉，简约素色床品套件')
    p46.images = ['p_60支纯棉四件套_1781524671003_1.png','p_60支纯棉四件套_1781524671003_2.png']
    // ── 汽车 ──
    let p47 = makeProduct(47, '倍思车载充电器', 79, 'p_倍思车载充电器_1781524671024_1.png', '汽车>车载电器', 'QC4.0+PD快充，双口输出')
    p47.images = ['p_倍思车载充电器_1781524671024_1.png','p_倍思车载充电器_1781524671024_2.png']
    let p48 = makeProduct(48, '70迈智能行车记录仪', 349, 'p_70迈智能行车记录仪_1781524671049_1.png', '汽车>汽车用品', '2K超清画质，ADAS驾驶辅助')
    p48.images = ['p_70迈智能行车记录仪_1781524671049_1.png','p_70迈智能行车记录仪_1781524671049_2.png']
    // ── 医药 ──
    let p49 = makeProduct(49, '云南白药创可贴', 19, 'p_云南白药创可贴_1781524671071_1.png', '医药>常备药', '轻巧透气，止血护创100片装')
    p49.images = ['p_云南白药创可贴_1781524671071_1.png','p_云南白药创可贴_1781524671071_2.png']
    let p50 = makeProduct(50, '汤臣倍健维生素C片', 68, 'p_汤臣倍健维生素C片_1781524671095_1.png', '医药>保健品', '针叶樱桃维C，增强抵抗力60片')
    p50.images = ['p_汤臣倍健维生素C片_1781524671095_1.png','p_汤臣倍健维生素C片_1781524671095_2.png']
    // ── 补充商品（51+ 留空显示占位） ──
    this.cachedProducts = [
      p1, p2, p3, p4, p5, p6, p7, p8, p9, p10,
      p11, p12, p13, p14, p15, p16, p17, p18, p19, p20,
      p21, p22, p23, p24, p25, p26, p27, p28, p29, p30,
      p31, p32, p33, p34, p35, p36, p37, p38, p39, p40,
      p41, p42, p43, p44, p45, p46, p47, p48, p49, p50
    ]
    this.cachedCategoryTree = [
      { name: '手机', children: ['华为', 'iPhone', '小米', 'OPPO', 'vivo', '三星', '荣耀'] },
      { name: '电脑', children: ['联想', '苹果', '华为', '华硕', '戴尔', '惠普'] },
      { name: '配件', children: ['耳机', '充电器', '数据线', '充电宝', '手机壳', '贴膜'] },
      { name: '家电', children: ['电视', '空调', '洗衣机', '冰箱', '扫地机器人', '热水器'] },
      { name: '生活', children: ['智能设备', '办公设备', '个护健康', '家居', '厨房用品'] },
      { name: '服装', children: ['男装', '女装', '运动鞋', '休闲鞋', '包包'] },
      { name: '美妆', children: ['护肤', '彩妆', '香水', '洗护'] },
      { name: '食品', children: ['零食', '茶饮', '生鲜', '酒水', '粮油调味'] },
      { name: '图书', children: ['文学', '科技', '教育', '生活', '童书'] },
      { name: '运动', children: ['运动鞋服', '健身器材', '户外装备', '瑜伽', '骑行'] },
      { name: '母婴', children: ['奶粉', '纸尿裤', '童装', '玩具', '推车'] },
      { name: '宠物', children: ['狗粮', '猫粮', '宠物用品', '宠物玩具', '宠物医疗'] },
      { name: '家装', children: ['家具', '灯具', '厨具', '家纺', '装饰'] },
      { name: '汽车', children: ['车载电器', '汽车用品', '维修保养', '车饰', '脚垫'] },
      { name: '医药', children: ['常备药', '保健品', '医疗器械', '计生用品', '眼镜'] },
    ]
  }

  getAll(): Product[] {
    return this.cachedProducts
  }

  getById(id: number): Product | undefined {
    for (let i = 0; i < this.cachedProducts.length; i++) {
      if (this.cachedProducts[i].id === id) {
        return this.cachedProducts[i]
      }
    }
    return undefined
  }

  async getProductDetail(id: number): Promise<Product | undefined> {
    try {
      let data: Object = await HttpClient.get('/products/' + id)
      let item = data as Record<string, Object>
      let p = new Product()
      p.id = item.id as number || 0
      p.name = item.name as string || ''
      p.price = item.price as number || 0
      p.image = item.image as string || ''
      p.images = item.images as string[] || []
      p.description = item.description as string || ''
      p.detailHtml = (item.detail_html as string) || ''
      p.category = item.category as string || ''
      p.specs = item.specs as ProductSpec[] || []
      p.skus = item.skus as SKU[] || []
        p.shopId = (item.shop_id as number) || 0
        p.shopName = (item.shop_name as string) || ''
        p.salesCount = (item.sales_count as number) || 0
        p.rating = (item.rating as number) || 0
        p.reviewCount = (item.reviewCount as number) || 0
        p.stock = (item.stock as number) || 0
      return p
    } catch (err) {
      Logger.error('ProductRepository.getProductDetail failed, fallback to cache: {0}', err instanceof Error ? err.message : '')
      return this.getById(id)
    }
  }

  async searchServer(keyword: string, sortBy: string = '默认', priceMin: number = 0, priceMax: number = 0, page: number = 1, pageSize: number = 20, category: string = ''): Promise<SearchResult> {
    try {
      let params = '?keyword=' + encodeURIComponent(keyword) + '&page=' + page + '&pageSize=' + pageSize
      if (priceMin > 0) params += '&priceMin=' + priceMin
      if (priceMax > 0) params += '&priceMax=' + priceMax
      if (category) params += '&category=' + encodeURIComponent(category)
      const sortMap: Record<string, string> = { '价格从低到高': 'price_asc', '价格从高到低': 'price_desc', '销量': 'sales' }
      const serverSort = sortMap[sortBy]
      if (serverSort) params += '&sortBy=' + serverSort
      let data: Object = await HttpClient.get('/products' + params)
      let resp = data as Record<string, Object>
      let raw = resp.items as Record<string, Object>[]
      let items = (raw || []).map(item => {
        let p = new Product()
        p.id = item.id as number || 0
        p.name = item.name as string || ''
        p.price = item.price as number || 0
        p.image = item.image as string || ''
        p.images = item.images as string[] || []
        p.description = item.description as string || ''
        p.detailHtml = (item.detail_html as string) || ''
        p.category = item.category as string || ''
        p.specs = item.specs as ProductSpec[] || []
        p.skus = item.skus as SKU[] || []
        p.shopId = (item.shop_id as number) || 0
        p.shopName = (item.shop_name as string) || ''
        p.salesCount = (item.sales_count as number) || 0
        p.rating = (item.rating as number) || 0
        p.reviewCount = (item.reviewCount as number) || 0
        p.stock = (item.stock as number) || 0
        return p
      })
      let total = resp.total as number || 0
      let result = new SearchResult()
      result.items = items
      result.total = total
      return result
    } catch (err) {
      Logger.error('ProductRepository.searchServer failed, fallback to local search: {0}', err instanceof Error ? err.message : '')
      let cat = category || '全部'
      let items = this.search(keyword, cat, sortBy, priceMin, priceMax)
      let result = new SearchResult()
      result.items = items
      result.total = items.length
      return result
    }
  }

  getShopName(productId: number): string {
    let p = this.getById(productId)
    return p ? p.shopName || '自营' : '自营'
  }

  getCategoryTree(): CategoryNode[] {
    return this.cachedCategoryTree
  }

  getParentCategories(): string[] {
    return this.cachedCategoryTree.map(c => c.name)
  }

  getChildren(parent: string): string[] {
    const node = this.cachedCategoryTree.find(c => c.name === parent)
    return node ? node.children : []
  }

  search(keyword: string, category: string, sortBy: string = '默认', priceMin: number = 0, priceMax: number = 0): Product[] {
    let result: Product[] = []
    let kw = keyword.trim().toLowerCase()
    for (let i = 0; i < this.cachedProducts.length; i++) {
      let p = this.cachedProducts[i]
      let matchCat = false
      if (category === '全部') {
        matchCat = true
      } else if (category.indexOf('>') !== -1) {
        matchCat = p.category === category
      } else {
        matchCat = p.category === category || p.category.startsWith(category + '>')
      }
      let matchSearch = kw === '' ||
        p.name.toLowerCase().includes(kw) ||
        p.category.toLowerCase().includes(kw) ||
        p.description.toLowerCase().includes(kw)
      let matchPrice = true
      if (priceMin > 0 && p.price < priceMin) {
        matchPrice = false
      }
      if (priceMax > 0 && p.price > priceMax) {
        matchPrice = false
      }
      if (matchCat && matchSearch && matchPrice) {
        result.push(p)
      }
    }
    if (sortBy === '价格从低到高') {
      result.sort((a, b) => a.price - b.price)
    } else if (sortBy === '价格从高到低') {
      result.sort((a, b) => b.price - a.price)
    } else if (sortBy === '销量') {
      result.sort((a, b) => (b.id * 1314 + 2048) - (a.id * 1314 + 2048))
    }
    return result
  }

  getSuggestions(query: string): string[] {
    let q = query.trim().toLowerCase()
    if (q === '') return []
    let seen: string[] = []
    let result: string[] = []
    for (let i = 0; i < this.cachedProducts.length; i++) {
      let p = this.cachedProducts[i]
      if (p.name.toLowerCase().includes(q) && seen.indexOf(p.name) === -1) {
        seen.push(p.name)
        result.push(p.name)
      }
      let parts = p.category.split('>')
      for (let j = 0; j < parts.length; j++) {
        let part = parts[j].trim()
        if (part.toLowerCase().includes(q) && seen.indexOf(part) === -1) {
          seen.push(part)
          result.push(part)
        }
      }
      if (result.length >= 8) break
    }
    return result
  }
}

export const productRepository = new ProductRepository()
