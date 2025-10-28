use array::{ArrayTrait, SpanTrait};
use orion::numbers::{FP16x16, FixedTrait};
use orion::operators::tensor::{FP16x16Tensor, Tensor, TensorTrait};

fn tensor() -> Tensor<FP16x16> {
    Tensor {
        shape: array![9, 1].span(),
        data: array![
            FP16x16 { mag: 15010, sign: true }, FP16x16 { mag: 27195, sign: true },
            FP16x16 { mag: 36261, sign: true }, FP16x16 { mag: 26590, sign: false },
            FP16x16 { mag: 23070, sign: false }, FP16x16 { mag: 29654, sign: false },
            FP16x16 { mag: 25429, sign: true }, FP16x16 { mag: 28541, sign: false },
            FP16x16 { mag: 27150, sign: true },
        ]
            .span(),
    }
}
