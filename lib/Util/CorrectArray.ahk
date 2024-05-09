class CorrectArray {

    Length => this.value.Length

    __Item[i] => this.value[i + 1]

    __New(array := []) {
        this.value := array
    }

    Push(item) {
        this.value.Push(item)
    }

    Pop() {
        this.value.Pop()
    }

    Clear() {
        this.value.Clear()
    }

}