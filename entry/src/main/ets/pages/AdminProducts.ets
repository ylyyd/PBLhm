import { adminRepository } from '../data/repository/AdminRepository'
import { productRepository, CategoryNode } from '../data/repository/ProductRepository'
import { AppColor, AppRadius, AppShadow } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppInput } from '../components/AppInput'

import { HeaderComponent } from '../components/HeaderComponent'
import { LoadingView, EmptyView } from '../components/StatusViews'
import { Product } from '../data/model/ProductModel'
import { ProductImage } from '../components/ProductImage'
import { ConfirmDialog } from '../components/DialogComponent'

class ProductDataSource implements IDataSource {
  private dataArray: Product[] = []

  pushData(data: Product[]): void {
    this.dataArray = data
  }

  totalCount(): number {
    return this.dataArray.length
  }

  getData(index: number): Product {
    return this.dataArray[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {}

  unregisterDataChangeListener(listener: DataChangeListener): void {}
}

@Entry
@Component
struct AdminProducts {
  @State products: Product[] = []
  @State productsDataSource: ProductDataSource = new ProductDataSource()
  @State isLoading: boolean = true
  @State showForm: boolean = false
  @State editingProduct: Product | null = null
  @State formName: string = ''
  @State formPrice: string = ''
  @State formImage: string = ''
  @State formCategory: string = ''
  @State formDesc: string = ''
  @State categoryTree: CategoryNode[] = []
  @State selectedParentIdx: number = -1
  @State selectedChildIdx: number = -1
  deleteDialogController: CustomDialogController | null = null

  async aboutToAppear(): Promise<void> {
    await this.loadProducts()
    this.categoryTree = productRepository.getCategoryTree()
  }

  async onPageShow(): Promise<void> {
    await this.loadProducts()
    this.categoryTree = productRepository.getCategoryTree()
  }

  async loadProducts(): Promise<void> {
    this.isLoading = true
    let data = await adminRepository.getProducts()
    this.products = data
    this.productsDataSource.pushData(data)
    this.isLoading = false
  }

  openAdd(): void {
    this.editingProduct = null
    this.formName = ''
    this.formPrice = ''
    this.formImage = ''
    this.formCategory = ''
    this.formDesc = ''
    this.selectedParentIdx = -1
    this.selectedChildIdx = -1
    this.showForm = true
  }

  openEdit(p: Product): void {
    this.editingProduct = p
    this.formName = p.name || ''
    this.formPrice = p.price.toString()
    this.formImage = p.image || ''
    this.formCategory = p.category || ''
    this.formDesc = p.description || ''
    // Pre-select category picker
    if (p.category) {
      let parts = p.category.split('>')
      this.selectedParentIdx = this.categoryTree.findIndex(c => c.name === parts[0])
      if (this.selectedParentIdx >= 0 && parts.length > 1) {
        let parent = this.categoryTree[this.selectedParentIdx]
        this.selectedChildIdx = parent.children.indexOf(parts[1])
      } else {
        this.selectedChildIdx = -1
      }
    } else {
      this.selectedParentIdx = -1
      this.selectedChildIdx = -1
    }
    this.showForm = true
  }

  async saveProduct(): Promise<void> {
    if (!(this.formName || '').trim() || !(this.formPrice || '').trim()) {
      this.getUIContext().getPromptAction().showToast({ message: '名称和价格不能为空' })
      return
    }
    let price = Number(this.formPrice)
    if (isNaN(price) || price <= 0) {
      this.getUIContext().getPromptAction().showToast({ message: '价格格式不正确' })
      return
    }
    let product: Product = new Product()
    product.name = this.formName.trim()
    product.price = price
    product.image = this.formImage.trim()
    product.category = this.formCategory.trim()
    product.description = this.formDesc.trim()
    if (this.editingProduct) {
      let ok = await adminRepository.updateProduct(this.editingProduct.id, product)
      if (ok) {
        this.getUIContext().getPromptAction().showToast({ message: '更新成功' })
        this.showForm = false
        await this.loadProducts()
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '更新失败' })
      }
    } else {
      let id = await adminRepository.addProduct(product)
      if (id !== undefined) {
        this.getUIContext().getPromptAction().showToast({ message: '添加成功' })
        this.showForm = false
        await this.loadProducts()
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '添加失败' })
      }
    }
  }

  deleteProduct(p: Product): void {
    let productId = p.id
    let productName = p.name
    this.deleteDialogController = new CustomDialogController({
      builder: ConfirmDialog({
        title: '确认删除',
        message: '确定要删除"' + productName + '"吗？',
        confirmText: '删除',
        onConfirm: async () => {
          let ok = await adminRepository.deleteProduct(productId)
          if (ok) {
            this.getUIContext().getPromptAction().showToast({ message: '已删除' })
            await this.loadProducts()
          } else {
            this.getUIContext().getPromptAction().showToast({ message: '删除失败' })
          }
        }
      }),
      autoCancel: true,
      customStyle: false
    })
    this.deleteDialogController.open()
  }

  build() {
    Stack() {
      Column() {
        HeaderComponent({ title: '商品管理', rightAction: '+ 添加', onRightAction: (): void => { this.openAdd() } })

        if (this.isLoading) {
          LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
        } else if (this.products.length === 0) {
          EmptyView({ message: '暂无商品', icon: $rawfile('empty_box.svg') }).layoutWeight(1).width('100%')
        } else {
          List({ space: 10 }) {
            LazyForEach(this.productsDataSource, (p: Product) => {
              ListItem() {
                Column() {
                  Row() {
                    ProductImage({ src: p.image })
                      .width(56).height(56).borderRadius(AppRadius.SM)
                    Column({ space: 4 }) {
                      Text(p.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text('¥' + p.price.toString()).fontSize(13).fontColor(AppColor.PRIMARY)
                      Text('分类: ' + (p.category || '未分类')).fontSize(11).fontColor(AppColor.textTertiary())
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })

                    AppButton({ text: '编辑', type: AppButtonType.PRIMARY,
                      buttonWidth: 0, buttonHeight: 30, fontSize: 12, buttonRadius: AppRadius.PILL,
                      buttonOnClick: () => { this.openEdit(p) } })
                      .constraintSize({ minWidth: 60 })
                    AppButton({ text: '删除', type: AppButtonType.OUTLINE,
                      buttonWidth: 0, buttonHeight: 30, fontSize: 12, buttonRadius: AppRadius.PILL,
                      buttonOnClick: () => { this.deleteProduct(p) } })
                      .constraintSize({ minWidth: 60 }).margin({ left: 6 })
                  }.width('100%')
                }.width('92%').padding(14).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
                .shadow(AppShadow.mid())
              }
            }, (p: Product) => p.id.toString())
          }
          .cachedCount(5)
          .width('100%').padding({ bottom: 24 })
          .layoutWeight(1)
        }
      }
      .width('100%').height('100%').backgroundColor(AppColor.bg())
 
       if (this.showForm) {
        Column() {
          Column({ space: 14 }) {
            Row() {
              Text(this.editingProduct ? '编辑商品' : '添加商品').fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
              Stack() {
                Circle().width(28).height(28).fill(AppColor.bg())
                Path().commands('M9,9 L19,19 M19,9 L9,19')
                  .stroke(AppColor.textTertiary()).strokeWidth(1.8).strokeLineCap(LineCapStyle.Round)
              }.width(28).height(28).onClick(() => { this.showForm = false })
            }.width('100%')

            AppInput({ placeholder: '商品名称', value: this.formName, onChange: (v: string) => { this.formName = v } })
            AppInput({ placeholder: '价格', value: this.formPrice, onChange: (v: string) => { this.formPrice = v }, type: InputType.Number })
            AppInput({ placeholder: '图片文件名 (如 mate60pro_1.png)', value: this.formImage, onChange: (v: string) => { this.formImage = v } })
            Text('分类').fontSize(13).fontColor(AppColor.textSecondary()).width('100%')
            if (this.categoryTree.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.categoryTree, (parent: CategoryNode, pIdx: number) => {
                  Text(parent.name).fontSize(13)
                    .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                    .margin({ right: 6, bottom: 6 })
                    .borderRadius(AppRadius.PILL)
                    .fontColor(this.selectedParentIdx === pIdx ? Color.White : AppColor.textPrimary())
                    .backgroundColor(this.selectedParentIdx === pIdx ? AppColor.PRIMARY : AppColor.inputBg())
                    .onClick(() => {
                      this.selectedParentIdx = pIdx
                      this.selectedChildIdx = -1
                      if (parent.children.length === 0) {
                        this.formCategory = parent.name
                      } else {
                        this.formCategory = parent.name + '>' + parent.children[0]
                        this.selectedChildIdx = 0
                      }
                    })
                })
              }.width('100%')
            }
            if (this.selectedParentIdx >= 0 && this.selectedParentIdx < this.categoryTree.length) {
              Flex({ wrap: FlexWrap.Wrap }) {
                Text('全部').fontSize(13)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 }).borderRadius(AppRadius.PILL)
                  .margin({ right: 6, bottom: 6 })
                  .fontColor(this.selectedChildIdx === -1 ? AppColor.PRIMARY : AppColor.textPrimary())
                  .backgroundColor(this.selectedChildIdx === -1 ? AppColor.primaryBg() : AppColor.inputBg())
                  .onClick(() => {
                    this.selectedChildIdx = -1
                    this.formCategory = this.categoryTree[this.selectedParentIdx].name
                  })
                ForEach(this.categoryTree[this.selectedParentIdx].children, (child: string, cIdx: number) => {
                  Text(child).fontSize(13)
                    .padding({ left: 12, right: 12, top: 5, bottom: 5 }).borderRadius(AppRadius.PILL)
                    .margin({ right: 6, bottom: 6 })
                    .fontColor(this.selectedChildIdx === cIdx ? Color.White : AppColor.textPrimary())
                    .backgroundColor(this.selectedChildIdx === cIdx ? AppColor.PRIMARY : AppColor.inputBg())
                    .onClick(() => {
                      this.selectedChildIdx = cIdx
                      let parentName = this.categoryTree[this.selectedParentIdx].name
                      this.formCategory = parentName + '>' + child
                    })
                })
              }.width('100%')
            }
            if (this.formCategory) {
              Text('已选: ' + this.formCategory).fontSize(12).fontColor(AppColor.PRIMARY).width('100%')
            }
            TextArea({ placeholder: '商品描述', text: this.formDesc })
              .onChange((v: string) => { this.formDesc = v }).height(80).backgroundColor(AppColor.inputBg()).borderRadius(AppRadius.SM).padding({ left: 12 })

            AppButton({ text: this.editingProduct ? '保存修改' : '确认添加',
              type: AppButtonType.PRIMARY, buttonWidth: '100%', buttonHeight: 48,
              fontSize: 15, fontWeight: FontWeight.Bold,
              buttonOnClick: () => { this.saveProduct() } })
          }.width('88%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }
        .width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
    }
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn }).opacity(0)
    PageTransitionExit({ duration: 250, curve: Curve.FastOutLinearIn }).opacity(0)
  }
}
