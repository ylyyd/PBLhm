import { Product } from './model/ProductModel'

interface DataChangeListener {
  onDataReloaded(): void
  onDataAdded(index: number): void
  onDataMoved(from: number, to: number): void
  onDataDeleted(index: number): void
  onDataChanged(index: number): void
}

interface IDataSource {
  totalCount(): number
  getData(index: number): Object | undefined
  registerDataChangeListener(listener: DataChangeListener): void
  unregisterDataChangeListener(listener: DataChangeListener): void
}

export class ProductDataSource implements IDataSource {
  private dataArr: Product[] = []
  private listeners: DataChangeListener[] = []

  setData(arr: Product[]): void {
    this.dataArr = arr
    for (let listener of this.listeners) {
      listener.onDataReloaded()
    }
  }

  totalCount(): number {
    return this.dataArr.length
  }

  getData(index: number): Object | undefined {
    if (index < 0 || index >= this.dataArr.length) {
      return undefined
    }
    return this.dataArr[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    let idx = this.listeners.indexOf(listener)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }
}
