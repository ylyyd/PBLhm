import { adminRepository } from '../data/repository/AdminRepository'
import { AppColor, AppRadius } from '../common/StyleConstants'
import { AppButton, AppButtonType } from '../components/AppButton'
import { AppInput } from '../components/AppInput'
import { HeaderComponent } from '../components/HeaderComponent'
import { LoadingView, EmptyView } from '../components/StatusViews'
import { ConfirmDialog } from '../components/DialogComponent'

interface CategoryItem {
  id: number
  name: string
  full_path: string
  level: number
  parent_id: number
  product_count: number
  icon: string
  children: CategoryItem[]
}

interface FlatCategory {
  id: number
  name: string
  depth: number
  productCount: number
  hasChildren: boolean
  parentId: number
  catRef: CategoryItem
}

function flattenTree(cats: CategoryItem[], depth: number, result: FlatCategory[]): FlatCategory[] {
  for (let c of cats) {
    result.push({
      id: c.id,
      name: c.name,
      depth: depth,
      productCount: c.product_count,
      hasChildren: c.children && c.children.length > 0,
      parentId: c.parent_id,
      catRef: c
    })
    if (c.children && c.children.length > 0) {
      flattenTree(c.children, depth + 1, result)
    }
  }
  return result
}

@Entry
@Component
struct AdminCategories {
  @State categories: CategoryItem[] = []
  @State flatCategories: FlatCategory[] = []
  @State isLoading: boolean = true
  @State showForm: boolean = false
  @State editingCategory: CategoryItem | null = null
  @State formName: string = ''
  @State formParentId: number = 0
  @State parentOptions: CategoryItem[] = []
  @State selectedParentIdx: number = -1
  deleteDialogController: CustomDialogController | null = null

  async aboutToAppear(): Promise<void> {
    await this.loadCategories()
  }

  async loadCategories(): Promise<void> {
    this.isLoading = true
    let resp = await adminRepository.getCategories() as Record<string, Object>
    let tree = resp.categories as CategoryItem[] || []
    let flat = resp.flat as CategoryItem[] || []
    this.categories = tree
    this.parentOptions = (flat as CategoryItem[]).filter(c => c.level === 1)
    this.flatCategories = flattenTree(tree, 0, [])
    this.isLoading = false
  }

  openAdd(): void {
    this.editingCategory = null
    this.formName = ''
    this.formParentId = 0
    this.selectedParentIdx = -1
    this.showForm = true
  }

  openEdit(cat: CategoryItem): void {
    this.editingCategory = cat
    this.formName = cat.name
    this.formParentId = cat.parent_id
    this.selectedParentIdx = cat.parent_id
      ? this.parentOptions.findIndex(p => p.id === cat.parent_id)
      : -1
    this.showForm = true
  }

  async saveCategory(): Promise<void> {
    if (!this.formName.trim()) {
      this.getUIContext().getPromptAction().showToast({ message: '分类名称不能为空' })
      return
    }
    if (this.editingCategory) {
      let updateFields: Record<string, Object> = {}
      updateFields['name'] = this.formName.trim()
      let ok = await adminRepository.updateCategory(this.editingCategory.id, updateFields)
      if (ok) {
        this.getUIContext().getPromptAction().showToast({ message: '更新成功' })
        this.showForm = false
        await this.loadCategories()
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '更新失败' })
      }
    } else {
      let parentId = this.selectedParentIdx >= 0 ? this.parentOptions[this.selectedParentIdx].id : undefined
      let ok = await adminRepository.addCategory(this.formName.trim(), parentId)
      if (ok) {
        this.getUIContext().getPromptAction().showToast({ message: '添加成功' })
        this.showForm = false
        await this.loadCategories()
      } else {
        this.getUIContext().getPromptAction().showToast({ message: '添加失败' })
      }
    }
  }

  deleteCategory(cat: CategoryItem): void {
    let catName = cat.name
    let msg = '确定要删除"' + catName + '"吗？'
    if (cat.product_count > 0) {
      msg += ' 该分类下有 ' + cat.product_count + ' 个商品。'
    }
    this.deleteDialogController = new CustomDialogController({
      builder: ConfirmDialog({
        title: '确认删除',
        message: msg,
        confirmText: '删除',
        onConfirm: async () => {
          let ok = await adminRepository.deleteCategory(cat.id)
          if (ok) {
            this.getUIContext().getPromptAction().showToast({ message: '已删除' })
            await this.loadCategories()
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

  countAll(cats: CategoryItem[]): number {
    let n = cats.length
    for (let c of cats) {
      if (c.children) n += this.countAll(c.children)
    }
    return n
  }

  build() {
    Stack() {
      Column() {
        HeaderComponent({ title: '分类管理', rightAction: '+ 添加', onRightAction: (): void => { this.openAdd() } })

        if (this.isLoading) {
          LoadingView({ message: '加载中...' }).layoutWeight(1).width('100%')
        } else if (this.categories.length === 0) {
          EmptyView({ message: '暂无分类', icon: $rawfile('empty_box.svg') }).layoutWeight(1).width('100%')
        } else {
          Scroll() {
            Column() {
              // Tree header
              Row() {
                Text('共 ' + this.countAll(this.categories) + ' 个分类')
                  .fontSize(12).fontColor(AppColor.textTertiary()).layoutWeight(1)
              }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 4 })

              Column() {
                ForEach(this.flatCategories, (fc: FlatCategory) => {
                  this.buildCategoryRow(fc)
                })
              }.width('100%').backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.MD)
            }.width('92%').padding({ bottom: 24 })
          }.layoutWeight(1).width('100%')
        }
      }.width('100%').height('100%').backgroundColor(AppColor.bg())

      // Add/Edit form overlay
      if (this.showForm) {
        Column() {
          Column({ space: 14 }) {
            Row() {
              Text(this.editingCategory ? '编辑分类' : '添加分类')
                .fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
              Stack() {
                Circle().width(28).height(28).fill(AppColor.bg())
                Path().commands('M9,9 L19,19 M19,9 L9,19')
                  .stroke(AppColor.textTertiary()).strokeWidth(1.8).strokeLineCap(LineCapStyle.Round)
              }.width(28).height(28).onClick(() => { this.showForm = false })
            }.width('100%')

            AppInput({
              placeholder: '分类名称',
              value: this.formName,
              onChange: (v: string) => { this.formName = v }
            })

            if (!this.editingCategory) {
              Text('所属上级分类（可选）').fontSize(13).fontColor(AppColor.textSecondary()).width('100%')
              if (this.parentOptions.length > 0) {
                Column() {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    Text('顶级分类').fontSize(13)
                      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                      .borderRadius(AppRadius.PILL)
                      .margin({ right: 6, bottom: 6 })
                      .fontColor(this.selectedParentIdx === -1 ? Color.White : AppColor.textPrimary())
                      .backgroundColor(this.selectedParentIdx === -1 ? AppColor.PRIMARY : AppColor.inputBg())
                      .onClick(() => { this.selectedParentIdx = -1; this.formParentId = 0 })
                    ForEach(this.parentOptions, (p: CategoryItem, idx: number) => {
                      Text(p.name).fontSize(13)
                        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                        .borderRadius(AppRadius.PILL)
                        .margin({ right: 6, bottom: 6 })
                        .fontColor(this.selectedParentIdx === idx ? Color.White : AppColor.textPrimary())
                        .backgroundColor(this.selectedParentIdx === idx ? AppColor.PRIMARY : AppColor.inputBg())
                        .onClick(() => { this.selectedParentIdx = idx; this.formParentId = p.id })
                    })
                  }.width('100%')
                }.width('100%')
              }
            }

            AppButton({ text: this.editingCategory ? '保存修改' : '确认添加',
              type: AppButtonType.PRIMARY, buttonWidth: '100%', buttonHeight: 48,
              fontSize: 15, fontWeight: FontWeight.Bold,
              buttonOnClick: () => { this.saveCategory() }
            })
          }.width('88%').padding(24).backgroundColor(AppColor.cardBg()).borderRadius(AppRadius.LG)
        }.width('100%').height('100%').backgroundColor(AppColor.OVERLAY)
          .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
    }
  }

  @Builder
  buildCategoryRow(item: FlatCategory) {
    Column() {
      Row() {
        Row() {
          if (item.hasChildren) {
            Image($rawfile('ic_chevron_right.svg')).width(14).height(14).margin({ right: 6 })
              .objectFit(ImageFit.Contain)
          } else {
            Text('· ').fontSize(16).fontColor(AppColor.textTertiary()).margin({ right: 4 })
          }
          Text(item.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColor.textPrimary())
          if (item.productCount > 0) {
            Text('(' + item.productCount + ')').fontSize(11).fontColor(AppColor.textTertiary()).margin({ left: 6 })
          }
        }.layoutWeight(1).alignItems(VerticalAlign.Center)
        Row({ space: 2 }) {
          AppButton({ text: '编辑', type: AppButtonType.TEXT,
            buttonWidth: 0, buttonHeight: 28, fontSize: 11,
            buttonOnClick: () => { this.openEdit(item.catRef) }
          })
          AppButton({ text: '删除', type: AppButtonType.TEXT,
            buttonWidth: 0, buttonHeight: 28, fontSize: 11,
            buttonOnClick: () => { this.deleteCategory(item.catRef) }
          })
        }
      }.width('100%').padding({ left: 12 + item.depth * 24, right: 12, top: 10, bottom: 10 })
    }.width('100%').backgroundColor(item.depth % 2 === 0 ? AppColor.cardBg() : AppColor.bg())
  }
}
